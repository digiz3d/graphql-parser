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
const parseObjectTypeDefinition = @import("ast/object_type_definition.zig").parseObjectTypeDefinition;
const parseUnionTypeDefinition = @import("ast/union_type_definition.zig").parseUnionTypeDefinition;
const parseScalarTypeDefinition = @import("ast/scalar_type_definition.zig").parseScalarTypeDefinition;
const parseSchemaDefinition = @import("ast/schema_definition.zig").parseSchemaDefinition;
const parseFragmentDefinition = @import("ast/fragment_definition.zig").parseFragmentDefinition;
const parseOperationDefinition = @import("ast/operation_definition.zig").parseOperationDefinition;
const parseDirectiveDefinition = @import("ast/directive_definition.zig").parseDirectiveDefinition;
const parseInterfaceTypeDefinition = @import("ast/interface_type_definition.zig").parseInterfaceTypeDefinition;
const parseSchemaExtension = @import("ast/schema_extension.zig").parseSchemaExtension;

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
    ExpectedAt,
    ExpectedBraceRight,
    ExpectedBracketLeft,
    ExpectedBracketRight,
    ExpectedColon,
    ExpectedDollar,
    ExpectedLeftParenthesis,
    ExpectedName,
    ExpectedNameNotOn,
    ExpectedOn,
    ExpectedRightParenthesis,
    ExpectedString,
    InvalidLocation,
    InvalidOperationType,
    MissingExpectedBrace,
    NotImplemented,
    UnexpectedExclamationMark,
    UnexpectedMemoryError,
    UnexpectedToken,
    WrongParentNode,
};

pub const Parser = struct {
    allocator: Allocator,
    index: usize = 0,

    const Reading = enum {
        root,
        fragment_definition,
        operation_definition,
        schema_definition,
        object_type_definition,
        union_type_definition,
        scalar_type_definition,
        directive_definition,
        interface_type_definition,
        schema_extension,
    };

    pub fn init(allocator: Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8) ParseError!Document {
        var tokenizer = Tokenizer.init(self.allocator, buffer);
        defer tokenizer.deinit();
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        defer self.allocator.free(tokens);
        const token = try self.processTokens(tokens);
        return token;
    }

    fn processTokens(self: *Parser, tokens: []Token) ParseError!Document {
        var documentNode = Document{
            .allocator = self.allocator,
            .definitions = ArrayList(ExecutableDefinition).init(self.allocator),
        };
        errdefer documentNode.deinit();

        state: switch (Reading.root) {
            Reading.root => {
                var token = self.peekNextToken(tokens) orelse break :state;

                if (token.tag == Token.Tag.eof) {
                    break :state;
                }

                const isDescription = token.tag == Token.Tag.string_literal or token.tag == Token.Tag.string_literal_block;
                if (isDescription) {
                    token = self.peekNextNextToken(tokens) orelse return ParseError.EmptyTokenList;
                }
                if (token.tag != Token.Tag.identifier) {
                    return ParseError.ExpectedName;
                }

                const tokenStr = token.getStringValue(self.allocator) catch return ParseError.UnexpectedMemoryError;
                defer self.allocator.free(tokenStr);

                const str = try self.getTokenValue(token);
                defer self.allocator.free(str);
                if (strEq(str, "query") or strEq(str, "mutation") or strEq(str, "subscription")) {
                    continue :state Reading.operation_definition;
                } else if (strEq(str, "fragment")) {
                    continue :state Reading.fragment_definition;
                } else if (strEq(str, "schema")) {
                    continue :state Reading.schema_definition;
                } else if (strEq(str, "type")) {
                    continue :state Reading.object_type_definition;
                } else if (strEq(str, "union")) {
                    continue :state Reading.union_type_definition;
                } else if (strEq(str, "scalar")) {
                    continue :state Reading.scalar_type_definition;
                } else if (strEq(str, "directive")) {
                    continue :state Reading.directive_definition;
                } else if (strEq(str, "interface")) {
                    continue :state Reading.interface_type_definition;
                } else if (strEq(str, "extend")) {
                    const nextToken = self.peekNextNextToken(tokens) orelse return ParseError.EmptyTokenList;
                    const nextTokenStr = nextToken.getStringValue(self.allocator) catch return ParseError.UnexpectedMemoryError;
                    defer self.allocator.free(nextTokenStr);

                    if (strEq(nextTokenStr, "schema")) {
                        continue :state Reading.schema_extension;
                    } else {
                        return ParseError.NotImplemented;
                    }
                }
                return ParseError.InvalidOperationType;
            },
            Reading.fragment_definition => {
                const fragmentDefinition = try parseFragmentDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .fragmentDefinition = fragmentDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.operation_definition => {
                const operationDefinition = try parseOperationDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .operationDefinition = operationDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.schema_definition => {
                const schemaDefinition = try parseSchemaDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .schemaDefinition = schemaDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.object_type_definition => {
                const objectTypeDefinition = try parseObjectTypeDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .objectTypeDefinition = objectTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.union_type_definition => {
                const unionTypeDefinition = try parseUnionTypeDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .unionTypeDefinition = unionTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.scalar_type_definition => {
                const scalarTypeDefinition = try parseScalarTypeDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .scalarTypeDefinition = scalarTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.directive_definition => {
                const directiveDefinition = try parseDirectiveDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .directiveDefinition = directiveDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.interface_type_definition => {
                const interfaceTypeDefinition = try parseInterfaceTypeDefinition(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .interfaceTypeDefinition = interfaceTypeDefinition,
                }) catch return ParseError.UnexpectedMemoryError;
                continue :state Reading.root;
            },
            Reading.schema_extension => {
                const schemaExtension = try parseSchemaExtension(self, tokens);
                documentNode.definitions.append(ExecutableDefinition{
                    .schemaExtension = schemaExtension,
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

    pub fn peekNextNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index + 1 >= tokens.len) {
            return null;
        }
        return tokens[self.index + 1];
    }

    pub fn consumeNextToken(self: *Parser, tokens: []Token) ?Token {
        if (self.index >= tokens.len) {
            return null;
        }
        const nextToken = tokens[self.index];
        self.index += 1;
        return nextToken;
    }

    pub fn getTokenValue(self: *Parser, token: Token) ParseError![]const u8 {
        const str = token.getStringValue(self.allocator) catch return ParseError.UnexpectedMemoryError;
        return str;
    }
};

test "initialize fragment" {
    var parser = Parser.init(testing.allocator);

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

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqualStrings(rootNode.definitions.items[0].fragmentDefinition.name, "Profile");
}

test "initialize query" {
    var parser = Parser.init(testing.allocator);

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

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqualStrings(rootNode.definitions.items[0].operationDefinition.name orelse "", "SomeQuery");
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[0].operationDefinition.operation);
}

test "initialize query without name" {
    var parser = Parser.init(testing.allocator);

    const buffer =
        \\query {
        \\  nickname: username
        \\}
    ;

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqual(null, rootNode.definitions.items[0].operationDefinition.name);
    try testing.expectEqual(OperationType.query, rootNode.definitions.items[0].operationDefinition.operation);
}

test "initialize mutation" {
    var parser = Parser.init(testing.allocator);

    const buffer =
        \\mutation SomeMutation($param: String = "123" @tolowercase) @SomeDecorator {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqualStrings("SomeMutation", rootNode.definitions.items[0].operationDefinition.name orelse "");
    try testing.expectEqual(OperationType.mutation, rootNode.definitions.items[0].operationDefinition.operation);
}

test "initialize subscription" {
    var parser = Parser.init(testing.allocator);

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

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqualStrings("SomeSubscription", rootNode.definitions.items[0].operationDefinition.name orelse "");
    try testing.expectEqual(OperationType.subscription, rootNode.definitions.items[0].operationDefinition.operation);
}

test "initialize schema" {
    var parser = Parser.init(testing.allocator);

    const buffer =
        \\schema {
        \\  query: Queryyyy
        \\  mutation: Mut
        \\  subscription: Sub
        \\}
    ;

    var rootNode = try parser.parse(buffer);
    defer rootNode.deinit();

    try testing.expectEqualStrings("query", rootNode.definitions.items[0].schemaDefinition.operationTypes[0].operation);
    try testing.expectEqualStrings("Queryyyy", rootNode.definitions.items[0].schemaDefinition.operationTypes[0].name);
    try testing.expectEqualStrings("mutation", rootNode.definitions.items[0].schemaDefinition.operationTypes[1].operation);
    try testing.expectEqualStrings("Mut", rootNode.definitions.items[0].schemaDefinition.operationTypes[1].name);
    try testing.expectEqualStrings("subscription", rootNode.definitions.items[0].schemaDefinition.operationTypes[2].operation);
    try testing.expectEqualStrings("Sub", rootNode.definitions.items[0].schemaDefinition.operationTypes[2].name);
}

// error cases
test "initialize invalid document " {
    var parser = Parser.init(testing.allocator);
    const buffer = "test { hello }";
    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.InvalidOperationType, rootNode);
}

test "initialize empty schema" {
    var parser = Parser.init(testing.allocator);
    const buffer = "schema {}";
    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment no name" {
    var parser = Parser.init(testing.allocator);
    const buffer = "fragment { hello }";
    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment name is on" {
    var parser = Parser.init(testing.allocator);
    const buffer = "fragment on on User { hello }";
    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
}

test "initialize invalid fragment name after on" {
    var parser = Parser.init(testing.allocator);
    const buffer = "fragment X on { hello }";
    const rootNode = parser.parse(buffer);
    try testing.expectError(ParseError.ExpectedName, rootNode);
}
