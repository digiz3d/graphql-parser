const std = @import("std");
const testing = @import("std").testing;
const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const printTokens = @import("tokenizer.zig").printTokens;

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
    UnexpectedMemoryError,
    WrongParentNode,
    EmptyTokenList,
    NotImplemented,
    InvalidOperationType,
    UnExpectedIdientifierToken,
};

pub const Parser = struct {
    allocator: Allocator,
    index: usize = 0,
    rootNode: ASTNode = undefined,
    currentNode: *ASTNode = undefined,

    const State = enum {
        reading_root,
        // reading_operation_definition,
        reading_fragment_definition,
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

        state: switch (State.reading_root) {
            State.reading_root => {
                if (tokens.len == 0) {
                    return self.rootNode;
                }
                const token = tokens[self.index];
                switch (token.tag) {
                    Token.Tag.identifier => {
                        const str = token.getValue();

                        if (std.mem.eql(u8, str, "query")) {
                            // TODO: implement
                        } else if (std.mem.eql(u8, str, "mutation")) {
                            // TODO: implement
                        } else if (std.mem.eql(u8, str, "subscription")) {
                            // TODO: implement
                        } else if (std.mem.eql(u8, str, "fragment")) {
                            continue :state State.reading_fragment_definition;
                        } else {
                            return ParseError.InvalidOperationType;
                        }
                    },
                    else => return ParseError.NotImplemented,
                }
            },
            State.reading_fragment_definition => {
                if (self.currentNode != &self.rootNode) {
                    return ParseError.WrongParentNode;
                }

                const fragmentNameToken = self.getNextToken(tokens) orelse return ParseError.EmptyTokenList;
                const fragmentName = fragmentNameToken.getValue();
                if (fragmentNameToken.tag != Token.Tag.identifier or std.mem.eql(u8, fragmentName, "on")) {
                    return ParseError.UnExpectedIdientifierToken;
                }

                const onToken = self.getNextToken(tokens) orelse return ParseError.EmptyTokenList;
                if (onToken.tag != Token.Tag.identifier or !std.mem.eql(u8, onToken.getValue(), "on")) {
                    return ParseError.UnExpectedIdientifierToken;
                }

                const typeConditionToken = self.getNextToken(tokens) orelse return ParseError.EmptyTokenList;
                if (typeConditionToken.tag != Token.Tag.identifier) {
                    return ParseError.UnExpectedIdientifierToken;
                }

                const newNode = ASTNode.init(self.allocator, ASTNodeType.FragmentDefinition, self.currentNode, fragmentName);
                self.currentNode.children.append(newNode) catch |err| switch (err) {
                    error.OutOfMemory => return ParseError.UnexpectedMemoryError,
                };
            },
        }

        return self.rootNode;
    }

    fn getNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index + 1 < tokens.len) {
            self.index += 1;
            return tokens[self.index];
        }
        return null;
    }
};

test "initialize document " {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "query { hello }";
    const content = buffer[0..];

    const rootNode = try parser.parse(content);
    try testing.expect(ASTNodeType.Document == rootNode.nodeType);
}

test "initialize invalid fragment" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment { hello }";
    const content = buffer[0..];

    const rootNode = parser.parse(content);
    try testing.expectError(ParseError.UnExpectedIdientifierToken, rootNode);
}

test "initialize fragment in document 1" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "fragment Oki on User { hello }";
    const content = buffer[0..];

    const rootNode = try parser.parse(content);
    try testing.expect(std.mem.eql(u8, rootNode.children.items[0].name.?, "Oki"));
    try testing.expect(ASTNodeType.Document == rootNode.nodeType);
}
