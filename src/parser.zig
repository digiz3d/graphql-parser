const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const allocPrint = std.fmt.allocPrint;

const tok = @import("tokenizer.zig");
const Token = tok.Token;
const Tokenizer = tok.Tokenizer;
const printTokens = tok.printTokens;

const input = @import("ast/input_value.zig");
const parseDirectives = @import("ast/directive.zig").parseDirectives;
const parseSelectionSet = @import("ast/selection_set.zig").parseSelectionSet;
const parseVariableDefinition = @import("ast/variable_definition.zig").parseVariableDefinition;
const parseOperationTypeDefinitions = @import("ast/operation_type_definition.zig").parseOperationTypeDefinitions;

const Document = @import("ast/document.zig").Document;
const ExecutableDefinition = @import("ast/executable_definition.zig").ExecutableDefinition;
const FragmentDefinition = @import("ast/fragment_definition.zig").FragmentDefinition;
const SchemaDefinition = @import("ast/schema_definition.zig").SchemaDefinition;
const op = @import("ast/operation_definition.zig");
const OperationType = op.OperationType;
const OperationDefinition = op.OperationDefinition;

const strEq = @import("utils/utils.zig").strEq;

pub const ParseError = error{
    EmptyTokenList,
    ExpectedBracketLeft,
    ExpectedBracketRight,
    ExpectedColon,
    ExpectedDollar,
    ExpectedName,
    ExpectedNameNotOn,
    ExpectedOn,
    ExpectedLeftParenthesis,
    ExpectedRightParenthesis,
    ExpectedString,
    InvalidOperationType,
    MissingExpectedBrace,
    NotImplemented,
    UnexpectedToken,
    UnexpectedMemoryError,
    WrongParentNode,
};

pub const Parser = struct {
    index: usize = 0,

    const Reading = enum {
        root,
        fragment_definition,
        query_definition,
        mutation_definition,
        subscription_definition,
        schema_definition,
    };

    pub fn init() Parser {
        return Parser{};
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8, allocator: Allocator) ParseError!Document {
        var tokenizer = Tokenizer.init(allocator, buffer);
        defer tokenizer.deinit();
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        defer allocator.free(tokens);
        const token = try self.processTokens(tokens, allocator);
        return token;
    }

    fn processTokens(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!Document {
        const definitions = ArrayList(ExecutableDefinition).init(allocator);

        var documentNode = Document{
            .allocator = allocator,
            .definitions = definitions,
        };

        state: switch (Reading.root) {
            Reading.root => {
                const token = self.peekNextToken(tokens) orelse break :state;

                if (token.tag == Token.Tag.eof) {
                    break :state;
                }
                if (token.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }

                const str = try self.getTokenValue(token, allocator);
                defer allocator.free(str);
                if (strEq(str, "query")) {
                    continue :state Reading.query_definition;
                } else if (strEq(str, "mutation")) {
                    continue :state Reading.mutation_definition;
                } else if (strEq(str, "subscription")) {
                    continue :state Reading.subscription_definition;
                } else if (strEq(str, "fragment")) {
                    continue :state Reading.fragment_definition;
                } else if (strEq(str, "schema")) {
                    continue :state Reading.schema_definition;
                }
                return ParseError.InvalidOperationType;
            },
            Reading.fragment_definition => {
                _ = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

                const fragmentNameToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                const fragmentName = try self.getTokenValue(fragmentNameToken, allocator);
                errdefer allocator.free(fragmentName);

                if (fragmentNameToken.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }
                if (strEq(fragmentName, "on")) {
                    return ParseError.ExpectedNameNotOn;
                }

                const onToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                const tokenName = try self.getTokenValue(onToken, allocator);
                defer allocator.free(tokenName);

                if (onToken.tag != Token.Tag.identifier or !strEq(tokenName, "on")) {
                    return ParseError.ExpectedOn;
                }

                const namedTypeToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                if (namedTypeToken.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }

                const directivesNodes = try parseDirectives(self, tokens, allocator);
                const selectionSetNode = try parseSelectionSet(self, tokens, allocator);

                const fragmentDefinitionNode = ExecutableDefinition{
                    .fragment = FragmentDefinition{
                        .allocator = allocator,
                        .name = fragmentName,
                        .directives = directivesNodes,
                        .selectionSet = selectionSetNode,
                    },
                };

                documentNode.definitions.append(fragmentDefinitionNode) catch return ParseError.UnexpectedMemoryError;

                continue :state Reading.root;
            },
            Reading.query_definition, Reading.mutation_definition, Reading.subscription_definition => |operationType| {
                _ = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

                var operationName: ?[]const u8 = null;
                if (self.peekNextToken(tokens).?.tag == Token.Tag.identifier) {
                    const operationNameToken = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
                    const name: ?[]const u8 = self.getTokenValue(operationNameToken, allocator) catch null;
                    operationName = name;
                }

                const variablesNodes = try parseVariableDefinition(self, tokens, allocator);
                const directivesNodes = try parseDirectives(self, tokens, allocator);
                const selectionSetNode = try parseSelectionSet(self, tokens, allocator);

                const fragmentDefinitionNode = ExecutableDefinition{
                    .operation = OperationDefinition{
                        .allocator = allocator,
                        .directives = directivesNodes,
                        .name = operationName,
                        .operation = switch (operationType) {
                            Reading.query_definition => OperationType.query,
                            Reading.mutation_definition => OperationType.mutation,
                            Reading.subscription_definition => OperationType.subscription,
                            else => unreachable,
                        },
                        .selectionSet = selectionSetNode,
                        .variableDefinitions = variablesNodes,
                    },
                };
                documentNode.definitions.append(fragmentDefinitionNode) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.schema_definition => {
                // Consume 'schema'
                _ = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

                const directivesNodes = try parseDirectives(self, tokens, allocator);

                const operationTypes = try parseOperationTypeDefinitions(self, tokens, allocator);

                documentNode.definitions.append(ExecutableDefinition{
                    .schema = SchemaDefinition{
                        .allocator = allocator,
                        .directives = directivesNodes,
                        .operationTypes = operationTypes,
                    },
                }) catch return ParseError.UnexpectedMemoryError;

                continue :state Reading.root;
            },
        }

        return documentNode;
    }

    pub fn peekNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index >= tokens.len) {
            return null;
        }
        return tokens[self.index];
    }

    pub fn consumeNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index >= tokens.len) {
            return null;
        }
        const nextToken = tokens[self.index];
        self.index += 1;
        return nextToken;
    }

    pub fn getTokenValue(_: *Parser, token: Token, allocator: Allocator) ParseError![]const u8 {
        const str = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError;
        return str;
    }
};

test "initialize fragment" {
    var parser = Parser.init();

    const buffer =
        \\fragment Profile on User @SomeDecorator
        \\  @AnotherOne(v: $var, i: 42, f: 0.1234e3 , s: "oui", b: true, n: null e: SOME_ENUM) {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqualStrings(rootNode.definitions.items[0].fragment.name, "Profile");
}

test "initialize query" {
    var parser = Parser.init();

    const buffer =
        \\query SomeQuery($someParams: [String!]!) @SomeDecorator
        \\  @AnotherOne(v: $someParams, i: 42, f: 0.1234e3 , s: "oui", b: true, n: null e: SOME_ENUM) {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\     ... OtherAvatarProps @whynot
        \\    ... on Avatar @hereToo {
        \\      test
        \\    }
        \\    createdAt
        \\  }
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqualStrings(rootNode.definitions.items[0].operation.name orelse "", "SomeQuery");
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[0].operation.operation);
}

test "initialize query without name" {
    var parser = Parser.init();

    const buffer =
        \\query {
        \\  nickname: username
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqual(null, rootNode.definitions.items[0].operation.name);
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[0].operation.operation);
}

test "initialize mutation" {
    var parser = Parser.init();

    const buffer =
        \\mutation SomeMutation($param: String = "123" @tolowercase) @SomeDecorator {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqualStrings("SomeMutation", rootNode.definitions.items[0].operation.name orelse "");
    try testing.expectEqual(OperationType.mutation, rootNode.definitions.items[0].operation.operation);
}

test "initialize subscription" {
    var parser = Parser.init();

    const buffer =
        \\subscription SomeSubscription @SomeDecorator #some comment
        \\{
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqualStrings("SomeSubscription", rootNode.definitions.items[0].operation.name orelse "");
    try testing.expectEqual(OperationType.subscription, rootNode.definitions.items[0].operation.operation);
}

test "initialize schema" {
    var parser = Parser.init();

    const buffer =
        \\schema {
        \\  query: Queryyyy
        \\  mutation: Mut
        \\  subscription: Sub
        \\}
    ;

    var rootNode = try parser.parse(buffer, testing.allocator);
    defer rootNode.deinit();

    try testing.expectEqualStrings("query", rootNode.definitions.items[0].schema.operationTypes[0].operation);
    try testing.expectEqualStrings("Queryyyy", rootNode.definitions.items[0].schema.operationTypes[0].name);
    try testing.expectEqualStrings("mutation", rootNode.definitions.items[0].schema.operationTypes[1].operation);
    try testing.expectEqualStrings("Mut", rootNode.definitions.items[0].schema.operationTypes[1].name);
    try testing.expectEqualStrings("subscription", rootNode.definitions.items[0].schema.operationTypes[2].operation);
    try testing.expectEqualStrings("Sub", rootNode.definitions.items[0].schema.operationTypes[2].name);
}

// error cases
test "initialize invalid document " {
    var parser = Parser.init();

    const buffer = "test { hello }";

    const rootNode = parser.parse(buffer, testing.allocator);

    try testing.expectError(ParseError.InvalidOperationType, rootNode);
}

test "initialize empty schema" {
    var parser = Parser.init();
    const buffer = "schema {}";
    const rootNode = parser.parse(buffer, testing.allocator);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment no name" {
    var parser = Parser.init();

    const buffer = "fragment { hello }";

    const rootNode = parser.parse(buffer, testing.allocator);

    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment name is on" {
    var parser = Parser.init();

    const buffer = "fragment on on User { hello }";

    const rootNode = parser.parse(buffer, testing.allocator);

    try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
}

test "initialize invalid fragment name after on" {
    var parser = Parser.init();

    const buffer = "fragment X on { hello }";

    const rootNode = parser.parse(buffer, testing.allocator);

    try testing.expectError(ParseError.ExpectedName, rootNode);
}
