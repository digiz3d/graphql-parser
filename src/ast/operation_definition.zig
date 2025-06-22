const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const VariableDefinition = @import("variable_definition.zig").VariableDefinition;
const SelectionSet = @import("selection_set.zig").SelectionSet;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;
const parseVariableDefinition = @import("variable_definition.zig").parseVariableDefinition;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseSelectionSet = @import("selection_set.zig").parseSelectionSet;
const strEq = @import("../utils/utils.zig").strEq;

pub const OperationType = enum {
    query,
    mutation,
    subscription,
};

pub const OperationDefinition = struct {
    allocator: Allocator,
    name: ?[]const u8,
    operation: OperationType,
    directives: []Directive,
    variableDefinitions: []VariableDefinition,
    selectionSet: SelectionSet,

    pub fn printAST(self: OperationDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- OperationDefinition\n", .{spaces});
        std.debug.print("{s}  operation = {s}\n", .{ spaces, switch (self.operation) {
            OperationType.query => "query",
            OperationType.mutation => "mutation",
            OperationType.subscription => "subscription",
        } });
        std.debug.print("{s}  name = {?s}\n", .{ spaces, self.name });
        std.debug.print("{s}  variableDefinitions: {d}\n", .{ spaces, self.variableDefinitions.len });
        for (self.variableDefinitions) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: OperationDefinition) void {
        if (self.name != null) {
            self.allocator.free(self.name.?);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.variableDefinitions) |item| {
            item.deinit();
        }
        self.allocator.free(self.variableDefinitions);
        self.selectionSet.deinit();
    }
};

pub fn parseOperationDefinition(parser: *Parser) ParseError!OperationDefinition {
    const operationTypeToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;

    const str = try parser.getTokenValue(operationTypeToken);
    defer parser.allocator.free(str);

    const operationType = if (strEq(str, "query"))
        OperationType.query
    else if (strEq(str, "mutation"))
        OperationType.mutation
    else if (strEq(str, "subscription"))
        OperationType.subscription
    else
        return ParseError.InvalidOperationType;

    var operationName: ?[]const u8 = null;
    if (parser.peekNextToken().?.tag == Token.Tag.identifier) {
        const operationNameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
        const name: ?[]const u8 = try parser.getTokenValue(operationNameToken);
        operationName = name;
    }

    const variablesNodes = try parseVariableDefinition(parser);
    const directivesNodes = try parseDirectives(parser);
    const selectionSetNode = try parseSelectionSet(parser);

    return OperationDefinition{
        .allocator = parser.allocator,
        .directives = directivesNodes,
        .name = operationName,
        .operation = operationType,
        .selectionSet = selectionSetNode,
        .variableDefinitions = variablesNodes,
    };
}

test "initialize query" {
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

    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationDefinition = try parseOperationDefinition(&parser);
    defer operationDefinition.deinit();

    try testing.expectEqualStrings(operationDefinition.name orelse "", "SomeQuery");
    try testing.expectEqual(OperationType.query, operationDefinition.operation);
}

test "initialize query without name" {
    const buffer =
        \\query {
        \\  nickname: username
        \\}
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationDefinition = try parseOperationDefinition(&parser);
    defer operationDefinition.deinit();

    try testing.expectEqual(null, operationDefinition.name);
    try testing.expectEqual(OperationType.query, operationDefinition.operation);
}

test "initialize mutation" {
    const buffer =
        \\mutation SomeMutation($param: String = "123" @tolowercase) @SomeDecorator {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationDefinition = try parseOperationDefinition(&parser);
    defer operationDefinition.deinit();

    try testing.expectEqualStrings("SomeMutation", operationDefinition.name orelse "");
    try testing.expectEqual(OperationType.mutation, operationDefinition.operation);
}

test "initialize subscription" {
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
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const operationDefinition = try parseOperationDefinition(&parser);
    defer operationDefinition.deinit();

    try testing.expectEqualStrings("SomeSubscription", operationDefinition.name orelse "");
    try testing.expectEqual(OperationType.subscription, operationDefinition.operation);
}
