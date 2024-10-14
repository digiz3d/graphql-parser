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
    parent: ?*ASTNode = null,

    pub fn init(allocator: Allocator, nodeType: ASTNodeType, parent: ?*ASTNode) ASTNode {
        return ASTNode{
            .token = null,
            .nodeType = nodeType,
            .children = ArrayList(ASTNode).init(allocator),
            .parent = parent,
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

    pub fn parse(self: *Parser, buffer: [:0]const u8) !ASTNode {
        var tokenizer = Tokenizer.init(self.allocator, buffer);
        const tokens = try tokenizer.getAllTokens();

        // TODO: make sense of the tokens
        // printTokens(tokens, buffer);
        return try self.processTokens(tokens);
    }

    fn processTokens(self: *Parser, tokens: []Token) ParseError!ASTNode {
        self.rootNode = ASTNode.init(
            self.allocator,
            ASTNodeType.Document,
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
                            //
                        } else if (std.mem.eql(u8, str, "mutation")) {
                            //
                        } else if (std.mem.eql(u8, str, "subscription")) {
                            //
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
                const newNode = ASTNode.init(self.allocator, ASTNodeType.FragmentDefinition, self.currentNode);
                if (self.currentNode != &self.rootNode) {
                    return ParseError.WrongParentNode;
                }
                self.currentNode.children.append(newNode) catch |err| switch (err) {
                    error.OutOfMemory => {
                        return ParseError.UnexpectedMemoryError;
                    },
                };
            },
        }

        return self.rootNode;
    }
};

test "initialize root node properly" {
    const allocator = testing.allocator;
    var parser = Parser.init(allocator);
    defer parser.deinit();

    const buffer = "query { hello }";
    const content = buffer[0..];

    const rootNode = try parser.parse(content);
    std.debug.print("rootNode: {}\n", .{rootNode});
}
