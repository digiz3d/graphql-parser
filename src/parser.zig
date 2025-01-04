const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const allocPrint = std.fmt.allocPrint;

const tok = @import("tokenizer.zig");
const Token = tok.Token;
const Tokenizer = tok.Tokenizer;
const printTokens = tok.printTokens;

const input = @import("input_value.zig");

const node = @import("./ast/index.zig");

inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn makeSpaceFromNumber(indent: usize, allocator: Allocator) []const u8 {
    var spaces = std.ArrayList(u8).init(allocator);
    const newIndent = indent * 2;
    for (0..newIndent) |_| {
        spaces.append(' ') catch return "";
    }
    return spaces.toOwnedSlice() catch return "";
}

pub const OperationType = enum {
    query,
    mutation,
    subscription,
};

const ParseError = error{
    EmptyTokenList,
    ExpectedColon,
    ExpectedDollar,
    ExpectedName,
    ExpectedNameNotOn,
    ExpectedOn,
    ExpectedRightParenthesis,
    ExpectedString,
    InvalidOperationType,
    MissingExpectedBrace,
    NotImplemented,
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
    };

    pub fn init() Parser {
        return Parser{};
    }

    pub fn parse(self: *Parser, buffer: [:0]const u8, allocator: Allocator) ParseError!node.Document {
        var tokenizer = Tokenizer.init(allocator, buffer);
        defer tokenizer.deinit();
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        defer allocator.free(tokens);
        const token = try self.processTokens(tokens, allocator);
        return token;
    }

    fn processTokens(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!node.Document {
        const definitions = ArrayList(node.ExecutableDefinition).init(allocator);

        var documentNode = node.Document{
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

                const directivesNodes = try self.readDirectives(tokens, allocator);
                const selectionSetNode = try self.readSelectionSet(tokens, allocator);

                const fragmentDefinitionNode = node.ExecutableDefinition{
                    .fragment = node.FragmentDefinition{
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

                const variablesNodes = try self.readVariableDefinition(tokens, allocator);
                const directivesNodes = try self.readDirectives(tokens, allocator);
                const selectionSetNode = try self.readSelectionSet(tokens, allocator);

                const fragmentDefinitionNode = node.ExecutableDefinition{
                    .operation = node.OperationDefinition{
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
        }

        return documentNode;
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

    fn readDirectives(self: *Parser, tokens: []Token, allocator: Allocator) ParseError![]node.Directive {
        var directives = ArrayList(node.Directive).init(allocator);
        var currentToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
        while (currentToken.tag == Token.Tag.punct_at) : (currentToken = self.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError) {
            _ = self.consumeNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

            const directiveNameToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

            if (directiveNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
            const directiveName = try self.getTokenValue(directiveNameToken, allocator);
            const arguments = try self.readArguments(tokens, allocator);
            const directiveNode = node.Directive{
                .allocator = allocator,
                .arguments = arguments,
                .name = directiveName,
            };
            directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
        }
        return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    fn readSelectionSet(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!node.SelectionSet {
        const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
        if (openBraceToken.tag != Token.Tag.punct_brace_left) {
            return ParseError.MissingExpectedBrace;
        }
        var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

        var selections = ArrayList(node.Selection).init(allocator);

        while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
            if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

            if (currentToken.tag == Token.Tag.punct_spread) {
                const onOrSpreadNameToken = self.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
                const onOrSpreadName = onOrSpreadNameToken.getStringValue(allocator) catch "";
                defer allocator.free(onOrSpreadName);

                var selection: node.Selection = undefined;
                if (strEq(onOrSpreadName, "on")) {
                    const typeConditionToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
                    if (typeConditionToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
                    const typeCondition = try self.getTokenValue(typeConditionToken, allocator);
                    const directives = try self.readDirectives(tokens, allocator);
                    const selectionSet = try self.readSelectionSet(tokens, allocator);
                    selection = node.Selection{
                        .inlineFragment = node.InlineFragment{
                            .allocator = allocator,
                            .typeCondition = typeCondition,
                            .directives = directives,
                            .selectionSet = selectionSet,
                        },
                    };
                } else {
                    const directives = try self.readDirectives(tokens, allocator);
                    const spreadName = allocator.dupe(u8, onOrSpreadName) catch return ParseError.UnexpectedMemoryError;
                    selection = node.Selection{
                        .fragmentSpread = node.FragmentSpread{
                            .allocator = allocator,
                            .name = spreadName,
                            .directives = directives,
                        },
                    };
                }
                selections.append(selection) catch return ParseError.UnexpectedMemoryError;
                continue;
            }

            const nameOrAlias = try self.getTokenValue(currentToken, allocator);
            const nextToken = self.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            const name, const alias = if (nextToken.tag == Token.Tag.punct_colon) assign: {
                // consume colon
                _ = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
                const finalNameToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
                const finalName = try self.getTokenValue(finalNameToken, allocator);
                break :assign .{ finalName, nameOrAlias };
            } else .{ nameOrAlias, null };

            const arguments = try self.readArguments(tokens, allocator);
            const directives = try self.readDirectives(tokens, allocator);

            const potentialNextLeftBrace = self.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            const selectionSet: ?node.SelectionSet = if (potentialNextLeftBrace.tag == Token.Tag.punct_brace_left) ok: {
                break :ok try self.readSelectionSet(tokens, allocator);
            } else null;

            const fieldNode = node.Selection{
                .field = node.Field{
                    .allocator = allocator,
                    .name = name,
                    .alias = alias,
                    .arguments = arguments,
                    .directives = directives,
                    .selectionSet = selectionSet,
                },
            };
            selections.append(fieldNode) catch return ParseError.UnexpectedMemoryError;
        }

        const selectionSetNode = node.SelectionSet{
            .allocator = allocator,
            .selections = selections.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        };
        return selectionSetNode;
    }

    fn readArguments(self: *Parser, tokens: []Token, allocator: Allocator) ParseError![]node.Argument {
        var arguments = ArrayList(node.Argument).init(allocator);

        var currentToken = self.peekNextToken(tokens) orelse
            return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        if (currentToken.tag != Token.Tag.punct_paren_left) {
            return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        }

        // consume the left parenthesis
        _ = self.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = self.peekNextToken(tokens) orelse
            return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
        {
            const argumentNameToken = self.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (argumentNameToken.tag != Token.Tag.identifier) return arguments.toOwnedSlice() catch return ParseError.ExpectedName;

            const argumentName = try self.getTokenValue(argumentNameToken, allocator);
            const colonToken = self.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (colonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

            const argumentValue = try self.readInputValue(tokens, allocator);

            const argument = node.Argument{
                .allocator = allocator,
                .name = argumentName,
                .value = argumentValue,
            };
            arguments.append(argument) catch return ParseError.UnexpectedMemoryError;

            currentToken = self.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError catch return ParseError.UnexpectedMemoryError;
        }

        // consume the right parenthesis
        _ = self.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis catch return ParseError.UnexpectedMemoryError;

        return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    fn readVariableDefinition(self: *Parser, tokens: []Token, allocator: Allocator) ParseError![]node.VariableDefinition {
        var variableDefinitions = ArrayList(node.VariableDefinition).init(allocator);

        var currentToken = self.peekNextToken(tokens) orelse
            return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        if (currentToken.tag != Token.Tag.punct_paren_left) {
            return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        }

        // consume the left parenthesis
        _ = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = self.peekNextToken(tokens) orelse
            return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
        {
            const variableDollarToken = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (variableDollarToken.tag != Token.Tag.punct_dollar) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedDollar;

            const variableNameToken = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (variableNameToken.tag != Token.Tag.identifier) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedName;
            const variableName = try self.getTokenValue(variableNameToken, allocator);

            const variableColonToken = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (variableColonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

            // TODO: properly parse type (NonNullType, ListType, NamedType)
            const variableTypeToken = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            if (variableTypeToken.tag != Token.Tag.identifier) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedName;
            const variableType = try self.getTokenValue(variableTypeToken, allocator);

            const nextToken = self.peekNextToken(tokens) orelse
                return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

            var defaultValue: ?input.InputValueData = null;

            if (nextToken.tag == Token.Tag.punct_equal) {
                _ = self.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
                // TODO: don't accept variables values there
                defaultValue = try self.readInputValue(tokens, allocator);
            }

            const directives = try self.readDirectives(tokens, allocator);

            const variableDefinition = node.VariableDefinition{
                .allocator = allocator,
                .name = variableName,
                .type = variableType,
                .defaultValue = defaultValue,
                .directives = directives,
            };
            variableDefinitions.append(variableDefinition) catch return ParseError.UnexpectedMemoryError;

            currentToken = self.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError catch return ParseError.UnexpectedMemoryError;
        }

        // consume the right parenthesis
        _ = self.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis catch return ParseError.UnexpectedMemoryError;

        return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    fn readInputValue(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!input.InputValueData {
        var token = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        var str = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError;
        defer allocator.free(str);

        var isVariable = false;

        if (token.tag == Token.Tag.punct_dollar) {
            token = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
            allocator.free(str);
            str = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError;
            isVariable = true;
        }

        switch (token.tag) {
            Token.Tag.integer_literal => return input.InputValueData{
                .int_value = input.IntValue{
                    .value = std.fmt.parseInt(i32, str, 10) catch return ParseError.UnexpectedMemoryError,
                },
            },
            Token.Tag.float_literal => return input.InputValueData{
                .float_value = input.FloatValue{
                    .value = std.fmt.parseFloat(f64, str) catch return ParseError.UnexpectedMemoryError,
                },
            },
            Token.Tag.string_literal => {
                const strCopy = allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
                return input.InputValueData{
                    .string_value = input.StringValue{
                        .value = strCopy,
                    },
                };
            },
            Token.Tag.identifier => {
                if (isVariable) {
                    const strCopy = allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
                    return input.InputValueData{
                        .variable = input.Variable{
                            .name = strCopy,
                        },
                    };
                } else if (strEq(str, "true")) {
                    return input.InputValueData{
                        .boolean_value = input.BooleanValue{
                            .value = true,
                        },
                    };
                } else if (strEq(str, "false")) {
                    return input.InputValueData{
                        .boolean_value = input.BooleanValue{
                            .value = false,
                        },
                    };
                } else if (strEq(str, "null")) {
                    return input.InputValueData{
                        .null_value = input.NullValue{},
                    };
                } else {
                    return input.InputValueData{
                        .enum_value = input.EnumValue{
                            .name = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError,
                        },
                    };
                }
            },
            // Token.Tag.punct_dollar => {
            //     const actualVariableName = self.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
            //     isVariable = true;
            //     continue :currentTag actualVariableName.tag;
            // },
            else => return ParseError.NotImplemented,
        }
        return ParseError.NotImplemented;
    }

    fn getTokenValue(_: *Parser, token: Token, allocator: Allocator) ParseError![]const u8 {
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

    try testing.expect(strEq(rootNode.definitions.items[0].fragment.name, "Profile"));
}

test "initialize query" {
    var parser = Parser.init();

    const buffer =
        \\query SomeQuery @SomeDecorator
        \\  @AnotherOne(v: $var, i: 42, f: 0.1234e3 , s: "oui", b: true, n: null e: SOME_ENUM) {
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

    try testing.expect(strEq(rootNode.definitions.items[0].operation.name orelse "", "SomeQuery"));
    try testing.expect(rootNode.definitions.items[0].operation.operation == OperationType.query);

    rootNode.printAST(0);
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

    try testing.expect(rootNode.definitions.items[0].operation.name == null);
    try testing.expect(rootNode.definitions.items[0].operation.operation == OperationType.query);
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

    try testing.expect(strEq(rootNode.definitions.items[0].operation.name orelse "", "SomeMutation"));
    try testing.expect(rootNode.definitions.items[0].operation.operation == OperationType.mutation);
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

    try testing.expect(strEq(rootNode.definitions.items[0].operation.name orelse "", "SomeSubscription"));
    try testing.expect(rootNode.definitions.items[0].operation.operation == OperationType.subscription);
}

// error cases
test "initialize invalid document " {
    var parser = Parser.init();

    const buffer = "test { hello }";

    const rootNode = parser.parse(buffer, testing.allocator);

    try testing.expectError(ParseError.InvalidOperationType, rootNode);
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
