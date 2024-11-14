const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const tok = @import("tokenizer.zig");
const Token = tok.Token;
const Tokenizer = tok.Tokenizer;
const printTokens = tok.printTokens;

inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

const DirectiveData = struct {
    name: []const u8,
    arguments: ArrayList([]const u8),

    pub fn deinit(self: DirectiveData) void {
        std.debug.print("  [DirectiveData.deinit] clearing arguments list ({s})\n", .{self.name});
        self.arguments.deinit();
    }
};

const DocumentData = struct {
    definitions: ArrayList(ASTNode),

    pub fn appendDefinition(self: *DocumentData, node: ASTNode) ParseError!void {
        self.definitions.append(node) catch return ParseError.UnexpectedMemoryError;
    }

    pub fn deinit(self: DocumentData) void {
        std.debug.print("  [DocumentData.deinit] clearing each definition and list \n", .{});
        self.definitions.deinit();
    }
};

const FieldData = struct {
    name: []const u8,
    alias: []const u8,
    arguments: ArrayList([]const u8),
    directives: ArrayList(ASTNode),

    pub fn deinit(self: FieldData) void {
        std.debug.print("  [FieldData.deinit] clearing each directive and list\n", .{});
        self.directives.deinit();
        std.debug.print("  [FieldData.deinit] clearing arguments list\n", .{});
        self.arguments.deinit();
    }
};

const FragmentDefinitionData = struct {
    name: []const u8,
    directives: ArrayList(ASTNode),
    selectionSet: *ASTNode,

    pub fn deinit(self: FragmentDefinitionData) void {
        std.debug.print("  [FragmentDefinitionData.deinit] clearing directive list\n", .{});
        self.directives.deinit();
        std.debug.print("  [FragmentDefinitionData.deinit] clearing selectionSet {} \n", .{self.selectionSet});
        self.selectionSet.deinit();
    }
};

const SelectionSetData = struct {
    selections: ArrayList(ASTNode),

    pub fn deinit(self: SelectionSetData) void {
        std.debug.print("  [SelectionSetData.deinit] clearing fields \n", .{});
        self.selections.deinit();
    }
};

const ASTNodeData = union(enum) {
    Directive: DirectiveData,
    Document: DocumentData,
    Field: FieldData,
    FragmentDefinition: FragmentDefinitionData,
    SelectionSet: SelectionSetData,

    // interface methods
    pub fn deinit(self: ASTNodeData) void {
        std.debug.print(" [Data.deinit] ({s})\n", .{@tagName(self)});
        switch (self) {
            inline else => |case| return case.deinit(),
        }
    }
};

pub const ASTNode = struct {
    data: ASTNodeData,

    pub fn init(data: ASTNodeData) ASTNode {
        return ASTNode{ .data = data };
    }

    pub fn deinit(self: *const ASTNode) void {
        std.debug.print("[ASTNode.deinit] ({s})\n", .{@tagName(self.data)});
        self.data.deinit();
    }

    pub fn printAST(self: *const ASTNode, currentIndent: usize, allocator: Allocator) void {
        std.debug.print("[ASTNode.printAST] ({s})\n", .{@tagName(self.data)});
        var spacesArray = std.ArrayList(u8).init(allocator);
        defer spacesArray.deinit();
        for (0..currentIndent) |_| {
            spacesArray.appendSlice("  ") catch {};
        }
        const spaces = spacesArray.items;

        std.debug.print("{s}{s}{s}\n", .{
            spaces,
            if (currentIndent == 0) "" else "- ",
            @tagName(self.data),
        });

        const nextIndent = currentIndent + 1;

        switch (self.data) {
            .Directive => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });
                std.debug.print("{s}  arguments: {d}\n", .{ spaces, data.arguments.capacity });
            },
            .Document => |data| {
                std.debug.print("{s}  definitions:\n", .{spaces});
                for (data.definitions.items) |*definition| {
                    definition.printAST(nextIndent, allocator);
                }
            },
            .Field => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });
                std.debug.print("{s}  alias = {s}\n", .{ spaces, if (data.alias.len > 0) data.alias else "none" });
            },
            .FragmentDefinition => |data| {
                std.debug.print("{s}  name = {s}\n", .{ spaces, data.name });

                std.debug.print("{s}  directives:\n", .{spaces});
                for (data.directives.items) |directive| {
                    directive.printAST(nextIndent, allocator);
                }

                std.debug.print("{s}  selectionSet:\n", .{spaces});
                data.selectionSet.printAST(nextIndent, allocator);
            },
            .SelectionSet => |data| {
                std.debug.print("{s}  selections:\n", .{spaces});
                for (data.selections.items) |item| {
                    item.printAST(nextIndent, allocator);
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
        // defer self.allocator.free(tokens);
        return try self.processTokens(tokens);
    }

    fn processTokens(self: *Parser, tokens: []Token) ParseError!ASTNode {
        const definitions = ArrayList(ASTNode).init(self.allocator);

        var rootNode = ASTNode.init(
            .{
                .Document = .{
                    .definitions = definitions,
                },
            },
        );
        self.currentNode = &rootNode;

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
                if (currentNode != &rootNode) {
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

                const directivesNodes = try self.readDirectivesNodes(tokens);
                var selectionSetNode = try self.readSelectionSetNode(tokens);

                const fragmentDefinitionNode = ASTNode.init(
                    .{
                        .FragmentDefinition = .{
                            .name = fragmentName,
                            .directives = directivesNodes,
                            .selectionSet = &selectionSetNode,
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

        return rootNode;
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
        const nextToken = tokens[self.index];
        self.index += 1;
        return nextToken;
    }

    fn readDirectivesNodes(self: *Parser, tokens: []Token) ParseError!ArrayList(ASTNode) {
        var directives = ArrayList(ASTNode).init(self.allocator);
        var currentToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
        while (currentToken.tag == Token.Tag.punct_at) : (currentToken = self.peekNextToken(tokens) orelse return directives) {
            _ = self.consumeNextToken(tokens) orelse
                return directives;

            const directiveNameToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
            if (directiveNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
            const arguments = ArrayList([]const u8).init(self.allocator);
            const directiveName = directiveNameToken.getValue();
            std.debug.print("directiveName: {s}\n", .{directiveName});
            const directiveNode = ASTNode.init(
                .{
                    .Directive = .{
                        .name = directiveName,
                        .arguments = arguments,
                    },
                },
            );
            directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
        }
        return directives;
    }

    fn readSelectionSetNode(self: *Parser, tokens: []Token) ParseError!ASTNode {
        const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
        if (openBraceToken.tag != Token.Tag.punct_brace_left) {
            return ParseError.MissingExpectedBrace;
        }
        var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

        var fieldsNodes = ArrayList(ASTNode).init(self.allocator);

        while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
            if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

            const arguments = ArrayList([]const u8).init(self.allocator);
            const directives = ArrayList(ASTNode).init(self.allocator);

            const fieldNode = ASTNode.init(
                .{ .Field = FieldData{
                    .name = currentToken.getValue(),
                    .alias = "",
                    .arguments = arguments,
                    .directives = directives,
                } },
            );
            fieldsNodes.append(fieldNode) catch return ParseError.UnexpectedMemoryError;
        }

        const selectionSetNode = ASTNode.init(
            .{
                .SelectionSet = .{
                    .selections = fieldsNodes,
                },
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

    const buffer = "fragment Oki on User @SomeDecorator @AnotherOne { hello }";

    const rootNode = try parser.parse(buffer);
    defer rootNode.deinit();
    try testing.expect(strEq(rootNode.data.Document.definitions.items[0].data.FragmentDefinition.name, "Oki"));
    try testing.expect(strEq(
        @tagName(rootNode.data),
        "Document",
    ));
    rootNode.printAST(0, testing.allocator);
}
