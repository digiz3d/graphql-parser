const std = @import("std");
const testing = @import("std").testing;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const printTokens = @import("tokenizer.zig").printTokens;

inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

const ASTNodeType = enum {
    Document,
    // ExecutableDefinition,
    // TypeSystemDefinitionOrExtension,
    OperationDefinition,
    FragmentDefinition,
    SelectionSet,
};

pub const ASTNode = struct {
    token: ?*Token,
    nodeType: ASTNodeType,
    children: ArrayList(ASTNode),

    // optional props
    name: ?[]const u8 = null,

    pub fn init(allocator: Allocator, nodeType: ASTNodeType, name: ?[]const u8) ASTNode {
        return ASTNode{
            .token = null,
            .nodeType = nodeType,
            .children = ArrayList(ASTNode).init(allocator),
            .name = name,
        };
    }

    pub fn deinit(self: *const ASTNode) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
    }

    pub fn appendChild(self: *ASTNode, node: ASTNode) ParseError!void {
        self.children.append(node) catch |err| switch (err) {
            error.OutOfMemory => return ParseError.UnexpectedMemoryError,
        };
    }

    pub fn print(self: *const ASTNode, currentIndentation: usize, allocator: Allocator) !void {
        var strrr = std.ArrayList(u8).init(allocator);
        defer strrr.deinit();
        for (0..currentIndentation) |_| {
            try strrr.appendSlice("  ");
        }
        const spaces = strrr.items;

        std.debug.print("{s}{s}{s}\n", .{ spaces, if (currentIndentation == 0) "" else "- ", @tagName(self.nodeType) });
        if (self.name != null) {
            std.debug.print("{s}  name = {?s}\n", .{ spaces, self.name });
        }

        std.debug.print("{s}  children:\n", .{spaces});
        for (self.children.items) |child| {
            try child.print(currentIndentation + 1, allocator);
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
        // operation_definition,
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
        self.rootNode = ASTNode.init(
            self.allocator,
            ASTNodeType.Document,
            null,
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
                var currentNode: *ASTNode = @ptrCast(self.currentNode);
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

                // TODO: implement optional directives, see https://spec.graphql.org/draft/#FragmentDefinition
                var nextToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
                while (nextToken.tag == Token.Tag.punct_at) : (nextToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList) {
                    _ = self.consumeNextToken(tokens); // at
                    _ = self.consumeNextToken(tokens); // name
                }

                const selectionSet = try self.readSelectionSet(tokens);
                var fragmentDefinitionNode = ASTNode.init(self.allocator, ASTNodeType.FragmentDefinition, fragmentName);
                try fragmentDefinitionNode.appendChild(selectionSet);
                try currentNode.appendChild(fragmentDefinitionNode);

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

    fn readSelectionSet(self: *Parser, tokens: []Token) ParseError!ASTNode {
        const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
        if (openBraceToken.tag != Token.Tag.punct_brace_left) {
            return ParseError.MissingExpectedBrace;
        }
        var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
        while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
            if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;
            // TODO: implement https://spec.graphql.org/draft/#sec-Selection-Sets
        }
        return ASTNode.init(self.allocator, ASTNodeType.SelectionSet, null);
    }
};

test "initialize invalid document " {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "test { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.InvalidOperationType, rootNode);
}

test "initialize non implemented query " {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "query Test { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.NotImplemented, rootNode);
}

test "initialize invalid fragment no name" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "fragment { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment name is on" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "fragment on on User { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
}

test "initialize invalid fragment name after on" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "fragment X on { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize fragment in document" {
    var parser = Parser.init(testing.allocator);
    defer parser.deinit();

    const buffer = "fragment Oki on User @SomeDecorator @AnotherOne { hello }";

    const rootNode = try parser.parse(buffer);
    try testing.expect(strEq(rootNode.children.items[0].name.?, "Oki"));
    try testing.expect(ASTNodeType.Document == rootNode.nodeType);
    try rootNode.print(0, testing.allocator);
}
