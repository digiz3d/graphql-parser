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
};

pub const ASTNode = struct {
    token: ?*Token,
    nodeType: ASTNodeType,
    children: ArrayList(ASTNode),

    // optional props
    parent: ?*ASTNode = null,
    name: ?[]const u8 = null,

    pub fn init(allocator: Allocator, nodeType: ASTNodeType, parent: ?*ASTNode, name: ?[]const u8) ASTNode {
        return ASTNode{
            .token = null,
            .nodeType = nodeType,
            .children = ArrayList(ASTNode).init(allocator),
            .parent = parent,
            .name = name,
        };
    }

    pub fn deinit(self: *const ASTNode) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
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
    UnexpectedEOF,
    UnexpectedMemoryError,
    WrongParentNode,
};

pub const Parser = struct {
    allocator: Allocator,
    index: usize = 0,
    rootNode: ASTNode = undefined,
    currentNode: *ASTNode = undefined,

    const Reading = enum {
        root,
        // operation_definition,
        fragment_definition,
        selection_set,
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
        // TODO: make sense of the tokens
        // printTokens(tokens, buffer);
        return try self.processTokens(tokens);
    }

    fn processTokens(self: *Parser, tokens: []Token) ParseError!ASTNode {
        self.rootNode = ASTNode.init(
            self.allocator,
            ASTNodeType.Document,
            null,
            null,
        );
        self.currentNode = &self.rootNode;

        state: switch (Reading.root) {
            Reading.root => {
                if (tokens.len == 0) {
                    break :state;
                }
                const token = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
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
                std.debug.print("unexpected name: {s}\n", .{str});
                return ParseError.InvalidOperationType;
            },
            Reading.fragment_definition => {
                if (self.currentNode != &self.rootNode) {
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

                const newNode = ASTNode.init(self.allocator, ASTNodeType.FragmentDefinition, self.currentNode, fragmentName);
                self.currentNode.children.append(newNode) catch |err| switch (err) {
                    error.OutOfMemory => return ParseError.UnexpectedMemoryError,
                };

                // TODO: implement optional directives, see https://spec.graphql.org/draft/#FragmentDefinition
                var nextToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
                while (nextToken.tag == Token.Tag.punct_at) : (nextToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList) {
                    _ = self.consumeNextToken(tokens); // at
                    _ = self.consumeNextToken(tokens); // name
                }

                continue :state Reading.selection_set;
            },
            Reading.selection_set => {
                const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
                if (openBraceToken.tag != Token.Tag.punct_brace_left) {
                    return ParseError.MissingExpectedBrace;
                }
                var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
                while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
                    if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;
                    // TODO: implement https://spec.graphql.org/draft/#sec-Selection-Sets
                }
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
};

test "initialize invalid document " {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "test { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.InvalidOperationType, rootNode);
}

test "initialize non implemented query " {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "query Test { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.NotImplemented, rootNode);
}

test "initialize invalid fragment no name" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment name is on" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment on on User { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
}

test "initialize invalid fragment name after on" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment X on { hello }";

    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize fragment in document 1" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment Oki on User { hello }";

    const rootNode = try parser.parse(buffer);
    try testing.expect(strEq(rootNode.children.items[0].name.?, "Oki"));
    try testing.expect(ASTNodeType.Document == rootNode.nodeType);
}
