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

const OperationType = enum {
    query,
    mutation,
    subscription,
};

const ArgumentData = struct {
    allocator: Allocator,
    name: []const u8,
    value: input.InputValueData,

    pub fn printAST(self: ArgumentData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ArgumentData\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        const value = self.value.getPrintableString(self.allocator);
        defer self.allocator.free(value);
        std.debug.print("{s}  value = {s}\n", .{ spaces, value });
    }

    pub fn deinit(self: ArgumentData) void {
        self.allocator.free(self.name);
        self.value.deinit(self.allocator);
    }
};

const DirectiveData = struct {
    allocator: Allocator,
    arguments: []ArgumentData,
    name: []const u8,

    pub fn printAST(self: DirectiveData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- DirectiveData\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: DirectiveData) void {
        self.allocator.free(self.name);
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
    }
};

const DocumentData = struct {
    allocator: Allocator,
    definitions: ArrayList(DefinitionData),

    pub fn printAST(self: DocumentData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- DocumentData\n", .{spaces});
        std.debug.print("{s}  definitions: {d}\n", .{ spaces, self.definitions.items.len });
        for (self.definitions.items) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: DocumentData) void {
        for (self.definitions.items) |item| {
            item.deinit();
        }
        self.definitions.deinit();
    }
};

const FieldData = struct {
    allocator: Allocator,
    name: []const u8,
    alias: ?[]const u8,
    arguments: []ArgumentData,
    directives: []DirectiveData,
    selectionSet: ?SelectionSetData,

    pub fn printAST(self: FieldData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FieldData\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        if (self.alias != null) {
            std.debug.print("{s}  alias = {?s}\n", .{ spaces, if (self.alias.?.len > 0) self.alias else "none" });
        } else {
            std.debug.print("{s}  alias = null\n", .{spaces});
        }
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        if (self.selectionSet != null) {
            std.debug.print("{s}  selectionSet: \n", .{spaces});
            self.selectionSet.?.printAST(indent + 1);
        } else {
            std.debug.print("{s}  selectionSet: null\n", .{spaces});
        }
    }

    pub fn deinit(self: FieldData) void {
        self.allocator.free(self.name);
        if (self.alias != null) {
            self.allocator.free(self.alias.?);
        }
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        if (self.selectionSet != null) {
            self.selectionSet.?.deinit();
        }
    }
};

// either a fragment or an operation
const DefinitionData = union(enum) {
    fragment: FragmentDefinitionData,
    operation: OperationDefinitionData,

    pub fn printAST(self: DefinitionData, indent: usize) void {
        switch (self) {
            DefinitionData.fragment => self.fragment.printAST(indent),
            DefinitionData.operation => self.operation.printAST(indent),
        }
    }

    pub fn deinit(self: DefinitionData) void {
        switch (self) {
            DefinitionData.fragment => self.fragment.deinit(),
            DefinitionData.operation => self.operation.deinit(),
        }
    }
};

const FragmentDefinitionData = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []DirectiveData,
    selectionSet: SelectionSetData,

    pub fn printAST(self: FragmentDefinitionData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FragmentDefinitionData\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: FragmentDefinitionData) void {
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
    }
};

const OperationDefinitionData = struct {
    allocator: Allocator,
    name: ?[]const u8,
    operation: OperationType,
    directives: []DirectiveData,
    // variableDefinitions: []VariableDefinitionData,
    selectionSet: SelectionSetData,

    pub fn printAST(self: OperationDefinitionData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- OperationDefinitionData\n", .{spaces});
        std.debug.print("{s}  operation = {s}\n", .{ spaces, switch (self.operation) {
            OperationType.query => "query",
            OperationType.mutation => "mutation",
            OperationType.subscription => "subscription",
        } });
        std.debug.print("{s}  name = {?s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: OperationDefinitionData) void {
        if (self.name != null) {
            self.allocator.free(self.name.?);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
    }
};

const SelectionSetData = struct {
    allocator: Allocator,
    fields: []FieldData,

    pub fn printAST(self: SelectionSetData, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SelectionSetData\n", .{spaces});
        std.debug.print("{s}  fields:\n", .{spaces});
        for (self.fields) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: SelectionSetData) void {
        for (self.fields) |item| {
            item.deinit();
        }
        self.allocator.free(self.fields);
    }
};

const ParseError = error{
    EmptyTokenList,
    ExpectedColon,
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

    pub fn parse(self: *Parser, buffer: [:0]const u8, allocator: Allocator) ParseError!DocumentData {
        var tokenizer = Tokenizer.init(allocator, buffer);
        defer tokenizer.deinit();
        const tokens = tokenizer.getAllTokens() catch return ParseError.UnexpectedMemoryError;
        defer allocator.free(tokens);
        const token = try self.processTokens(tokens, allocator);
        return token;
    }

    fn processTokens(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!DocumentData {
        const definitions = ArrayList(DefinitionData).init(allocator);

        var documentNode = DocumentData{
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

                const fragmentDefinitionNode = DefinitionData{
                    .fragment = FragmentDefinitionData{
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

                const directivesNodes = try self.readDirectives(tokens, allocator);
                const selectionSetNode = try self.readSelectionSet(tokens, allocator);

                const fragmentDefinitionNode = DefinitionData{
                    .operation = OperationDefinitionData{
                        .allocator = allocator,
                        .operation = switch (operationType) {
                            Reading.query_definition => OperationType.query,
                            Reading.mutation_definition => OperationType.mutation,
                            Reading.subscription_definition => OperationType.subscription,
                            else => unreachable,
                        },
                        .name = operationName,
                        .directives = directivesNodes,
                        .selectionSet = selectionSetNode,
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

    fn readDirectives(self: *Parser, tokens: []Token, allocator: Allocator) ParseError![]DirectiveData {
        var directives = ArrayList(DirectiveData).init(allocator);
        var currentToken = self.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
        while (currentToken.tag == Token.Tag.punct_at) : (currentToken = self.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError) {
            _ = self.consumeNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

            const directiveNameToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

            if (directiveNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
            const directiveName = try self.getTokenValue(directiveNameToken, allocator);
            const arguments = try self.readArguments(tokens, allocator);
            const directiveNode = DirectiveData{
                .allocator = allocator,
                .arguments = arguments,
                .name = directiveName,
            };
            directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
        }
        return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    fn readSelectionSet(self: *Parser, tokens: []Token, allocator: Allocator) ParseError!SelectionSetData {
        const openBraceToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
        if (openBraceToken.tag != Token.Tag.punct_brace_left) {
            return ParseError.MissingExpectedBrace;
        }
        var currentToken = self.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

        var fieldsNodes = ArrayList(FieldData).init(allocator);

        while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = self.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
            if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

            var directives = ArrayList(DirectiveData).init(allocator);

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

            const potentialNextLeftBrace = self.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            const selectionSet = if (potentialNextLeftBrace.tag == Token.Tag.punct_brace_left) ok: {
                break :ok try self.readSelectionSet(tokens, allocator);
            } else null;

            const fieldNode = FieldData{
                .allocator = allocator,
                .name = name,
                .alias = alias,
                .arguments = arguments,
                .directives = directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
                .selectionSet = selectionSet,
            };
            fieldsNodes.append(fieldNode) catch return ParseError.UnexpectedMemoryError;
        }

        const selectionSetNode = SelectionSetData{
            .allocator = allocator,
            .fields = fieldsNodes.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        };
        return selectionSetNode;
    }

    fn readArguments(self: *Parser, tokens: []Token, allocator: Allocator) ParseError![]ArgumentData {
        var arguments = ArrayList(ArgumentData).init(allocator);

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

            const argument = ArgumentData{
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
                // TODO: check why the spec uses "true" and "false" but implementations use "True" and "False"
                if (isVariable) {
                    const strCopy = allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
                    return input.InputValueData{
                        .variable = input.Variable{
                            .name = strCopy,
                        },
                    };
                } else if (strEq(str, "true") or strEq(str, "True")) {
                    return input.InputValueData{
                        .boolean_value = input.BooleanValue{
                            .value = true,
                        },
                    };
                } else if (strEq(str, "false") or strEq(str, "False")) {
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
        \\  @AnotherOne(v: $var, i: 42, f: 0.1234e3 , s: "oui", b: True, n: null e: SOME_ENUM) { 
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

    rootNode.printAST(0);
}

test "initialize query" {
    var parser = Parser.init();

    const buffer =
        \\query SomeQuery @SomeDecorator 
        \\  @AnotherOne(v: $var, i: 42, f: 0.1234e3 , s: "oui", b: True, n: null e: SOME_ENUM) { 
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
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

    rootNode.printAST(0);
}

test "initialize mutation" {
    var parser = Parser.init();

    const buffer =
        \\mutation SomeMutation @SomeDecorator { 
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

    rootNode.printAST(0);
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

    rootNode.printAST(0);
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
