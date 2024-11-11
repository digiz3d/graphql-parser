const std = @import("std");
const testing = @import("std").testing;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

const tok = @import("tokenizer.zig");
const Token = tok.Token;
const Tokenizer = tok.Tokenizer;
const printTokens = tok.printTokens;

inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

const ASTNodeType = enum {
    Directive,
    Document,
    Field,
    FragmentDefinition,
    SelectionSet,
};

const DirectiveData = struct {
    name: []const u8,
    arguments: [][]const u8,

    pub fn deinit(_: DirectiveData) void {
        std.debug.print("  [DirectiveData.deinit] clearing nothing\n", .{});
    }
};

const DocumentData = struct {
    definitions: ArrayList(ASTNode),

    pub fn appendDefinition(self: *DocumentData, node: ASTNode) ParseError!void {
        self.definitions.append(node) catch return ParseError.UnexpectedMemoryError;
    }

    pub fn deinit(self: DocumentData) void {
        std.debug.print("  [DocumentData.deinit] clearing each definition \n", .{});
        for (self.definitions.items) |definition| {
            definition.deinit();
        }
        // self.definitions.deinit();
    }
};

const FieldData = struct {
    name: []const u8,
    alias: []const u8,
    arguments: [][]const u8,
    directives: []ASTNode,
    selectionSet: ?*ASTNode,

    pub fn deinit(self: FieldData) void {
        std.debug.print("  [FieldData.deinit] clearing directives\n", .{});
        for (self.directives) |directive| {
            directive.deinit();
        }
        // if (self.selectionSet != null) {
        //     self.selectionSet.?.deinit();
        // }
    }
};

const FragmentDefinitionData = struct {
    name: []const u8,
    directives: []ASTNode,
    selectionSet: *ASTNode,

    pub fn deinit(self: FragmentDefinitionData) void {
        std.debug.print("  [FragmentDefinitionData.deinit] clearing each directive\n", .{});
        for (self.directives) |directive| {
            directive.deinit();
        }
        // self.selectionSet.deinit();
    }
};

const SelectionSetData = struct {
    selections: []ASTNode,

    pub fn deinit(_: SelectionSetData) void {
        std.debug.print("  [SelectionSetData.deinit] clearing nothing\n", .{});
        // for (self.selections) |selection| {
        //     selection.deinit();
        // }
    }
};

const Data = union(ASTNodeType) {
    Directive: DirectiveData,
    Document: DocumentData,
    Field: FieldData,
    FragmentDefinition: FragmentDefinitionData,
    SelectionSet: SelectionSetData,

    // interface methods
    pub fn deinit(self: Data) void {
        std.debug.print(" [Data.deinit] ({s})\n", .{@tagName(self)});
        switch (self) {
            inline else => |case| return case.deinit(),
        }
    }
};

pub const ASTNode = struct {
    nodeType: ASTNodeType,
    data: Data,

    pub fn init(nodeType: ASTNodeType, data: Data) ASTNode {
        return ASTNode{
            .nodeType = nodeType,
            .data = data,
        };
    }

    pub fn deinit(self: *const ASTNode) void {
        std.debug.print("[ASTNode.deinit] ({s})\n", .{@tagName(self.data)});
        self.data.deinit();
    }

    pub fn printAST(self: *const ASTNode, currentIndentation: usize, allocator: Allocator) void {
        var strrr = std.ArrayList(u8).init(allocator);
        defer strrr.deinit();
        for (0..currentIndentation) |_| {
            strrr.appendSlice("  ") catch {};
        }
        const spaces = strrr.items;

        std.debug.print("{s}{s}{s}\n", .{
            spaces,
            if (currentIndentation == 0) "" else "- ",
            @tagName(self.nodeType),
        });

        switch (self.data) {
            .Directive => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });

                std.debug.print("{s}  arguments:\n", .{spaces});
                // for (data.arguments) |argument| {
                std.debug.print("{s}    {s}\n", .{ spaces, data.arguments });
                // }
            },
            .Document => |data| {
                std.debug.print("{s}  definitions:\n", .{spaces});
                for (data.definitions.items) |*definition| {
                    definition.printAST(currentIndentation + 1, allocator);
                }
            },
            .Field => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });
                std.debug.print("{s}  alias = {s}\n", .{ spaces, if (data.alias.len > 0) data.alias else "none" });
            },
            .FragmentDefinition => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });

                std.debug.print("{s}  directives:\n", .{spaces});
                for (data.directives) |directive| {
                    directive.printAST(currentIndentation + 1, allocator);
                }

                std.debug.print("{s}  selectionSet:\n", .{spaces});
                data.selectionSet.printAST(currentIndentation + 1, allocator);
            },
            .SelectionSet => |data| {
                std.debug.print("{s}  selections:\n", .{spaces});
                for (data.selections) |selection| {
                    selection.printAST(currentIndentation + 1, allocator);
                }
            },
        }
    }
};

const ParseError = error{
    EmptyTokenList,
    ExpectedName,
    ExpectedNameNotOn,
    ExpectedOn,
    InvalidOperationType,
    MissingExpectedBrace,
    NotImplemented,
    UnexpectedMemoryError,
    WrongParentNode,
};

pub const Parser = struct {
    allocator: Allocator,
    index: usize = 0,
    rootNode: ASTNode = undefined,
    currentNode: ?*ASTNode = null,

    const Reading = enum {
        root,
        fragment_definition,
    };

    pub fn init(allocator: Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    pub fn deinit(self: *Parser) void {
        self.rootNode.deinit();
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8) ParseError!ASTNode {
        var tokenizer = Tokenizer.init(self.allocator, buffer);
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        defer self.allocator.free(tokens);
        return try self.processTokens(tokens);
    }

    fn processTokens(self: *Parser, tokens: []Token) ParseError!ASTNode {
        const definitions = ArrayList(ASTNode).init(self.allocator);

        self.rootNode = ASTNode.init(
            ASTNodeType.Document,
            .{
                .Document = .{
                    .definitions = definitions,
                },
            },
        );
        self.currentNode = &self.rootNode;

        state: switch (Reading.root) {
            Reading.root => {
                const token = self.peekNextToken(tokens) orelse break :state;

                if (token.tag == Token.Tag.eof) {
                    break :state;
                }
                if (token.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }

                const str = token.getValue();
                if (strEq(str, "query")) {
                    // TODO: implement
                    return ParseError.NotImplemented;
                } else if (strEq(str, "mutation")) {
                    // TODO: implement
                    return ParseError.NotImplemented;
                } else if (strEq(str, "subscription")) {
                    // TODO: implement
                    return ParseError.NotImplemented;
                } else if (strEq(str, "fragment")) {
                    continue :state Reading.fragment_definition;
                }
                return ParseError.InvalidOperationType;
            },
            Reading.fragment_definition => {
                if (self.currentNode == null) unreachable;
                const currentNode: *ASTNode = @ptrCast(self.currentNode);
                if (currentNode != &self.rootNode) {
                    return ParseError.WrongParentNode;
                }

                _ = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

                const fragmentNameToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                const fragmentName = fragmentNameToken.getValue();
                if (fragmentNameToken.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }
                if (strEq(fragmentName, "on")) {
                    return ParseError.ExpectedNameNotOn;
                }

                const onToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                if (onToken.tag != Token.Tag.identifier or !strEq(onToken.getValue(), "on")) {
                    return ParseError.ExpectedOn;
                }

                const namedTypeToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                if (namedTypeToken.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }

                const directives = try self.readDirectives(tokens);
                var selectionSet = try self.readSelectionSet(tokens);

                const fragmentDefinitionNode = ASTNode.init(
                    ASTNodeType.FragmentDefinition,
                    .{
                        .FragmentDefinition = .{
                            .name = fragmentName,
                            .directives = directives,
                            .selectionSet = &selectionSet,
                        },
                    },
                );
                switch (currentNode.data) {
                    .Document => |*doc| {
                        try doc.appendDefinition(fragmentDefinitionNode);
                    },
                    else => unreachable,
                }

                continue :state Reading.root;
            },
        }

        return self.rootNode;
    }

    fn peekNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index >= tokens.len) {
            return null;
        }
        return tokens[self.index];
    }

    fn consumeNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index >= tokens.len) {
            return null;
        }
        defer self.index += 1;
        return tokens[self.index];
    }

    fn readDirectives(self: *Parser, tokens: []Token) ParseError![]ASTNode {
        var directives = ArrayList(ASTNode).init(self.allocator);
        var currentToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
        while (currentToken.tag == Token.Tag.punct_at) : (currentToken = self.peekNextToken(tokens) orelse
            return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
        {
            _ = self.consumeNextToken(tokens) orelse
                return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            const directiveNameToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
            if (directiveNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
            var arguments = ArrayList([]const u8).init(self.allocator);
            const directiveNode = ASTNode.init(
                ASTNodeType.Directive,
                .{
                    .Directive = .{
                        .name = directiveNameToken.getValue(),
                        .arguments = arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
                    },
                },
            );
            directives.append(directiveNode) catch |err| switch (err) {
                error.OutOfMemory => return ParseError.UnexpectedMemoryError,
            };
        }
        return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    fn readSelectionSet(self: *Parser, tokens: []Token) ParseError!ASTNode {
        const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
        if (openBraceToken.tag != Token.Tag.punct_brace_left) {
            return ParseError.MissingExpectedBrace;
        }
        var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

        var selections = ArrayList(ASTNode).init(self.allocator);

        while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
            if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

            var arguments = ArrayList([]const u8).init(self.allocator);
            var directives = ArrayList(ASTNode).init(self.allocator);

            const fieldNode = ASTNode.init(
                ASTNodeType.Field,
                .{
                    .Field = .{
                        .alias = "",
                        .name = currentToken.getValue(),
                        .arguments = arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
                        .directives = directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
                        .selectionSet = null,
                    },
                },
            );
            selections.append(fieldNode) catch return ParseError.UnexpectedMemoryError;
        }

        const selectionSetData = SelectionSetData{
            .selections = selections.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        };
        const selectionSetNode = ASTNode.init(
            ASTNodeType.SelectionSet,
            .{
                .SelectionSet = selectionSetData,
            },
        );

        return selectionSetNode;
    }
};

// test "initialize invalid document " {
//     var parser = Parser.init(testing.allocator);
//     defer parser.deinit();

//     const buffer = "test { hello }";

//     const rootNode = parser.parse(buffer);
//     try testing.expectError(ParseError.InvalidOperationType, rootNode);
// }

// test "initialize non implemented query " {
//     var parser = Parser.init(testing.allocator);
//     defer parser.deinit();

//     const buffer = "query Test { hello }";

//     const rootNode = parser.parse(buffer);
//     try testing.expectError(ParseError.NotImplemented, rootNode);
// }

// test "initialize invalid fragment no name" {
//     var parser = Parser.init(testing.allocator);
//     defer parser.deinit();

//     const buffer = "fragment { hello }";

//     const rootNode = parser.parse(buffer);
//     try testing.expectError(ParseError.ExpectedName, rootNode);
// }

// test "initialize invalid fragment name is on" {
//     var parser = Parser.init(testing.allocator);
//     defer parser.deinit();

//     const buffer = "fragment on on User { hello }";

//     const rootNode = parser.parse(buffer);
//     try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
// }

// test "initialize invalid fragment name after on" {
//     var parser = Parser.init(testing.allocator);
//     defer parser.deinit();

//     const buffer = "fragment X on { hello }";

//     const rootNode = parser.parse(buffer);
//     try testing.expectError(ParseError.ExpectedName, rootNode);
// }

test "initialize fragment in document" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "fragment Oki on User @SomeDecorator @AnotherOne { hello }";

    const rootNode = try parser.parse(buffer);
    try testing.expect(strEq(rootNode.data.Document.definitions.items[0].data.FragmentDefinition.name, "Oki"));
    try testing.expect(ASTNodeType.Document == rootNode.nodeType);
    rootNode.printAST(0, testing.allocator);
}
