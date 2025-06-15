const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const VariableDefinition = @import("variable_definition.zig").VariableDefinition;
const SelectionSet = @import("selection_set.zig").SelectionSet;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
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

pub fn parseOperationDefinition(
    parser: *Parser,
    tokens: []Token,
    allocator: Allocator,
) ParseError!OperationDefinition {
    const operationTypeToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    if (operationTypeToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const str = try parser.getTokenValue(operationTypeToken, allocator);
    defer allocator.free(str);

    const operationType = if (strEq(str, "query"))
        OperationType.query
    else if (strEq(str, "mutation"))
        OperationType.mutation
    else if (strEq(str, "subscription"))
        OperationType.subscription
    else
        return ParseError.InvalidOperationType;

    var operationName: ?[]const u8 = null;
    if (parser.peekNextToken(tokens).?.tag == Token.Tag.identifier) {
        const operationNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        const name: ?[]const u8 = parser.getTokenValue(operationNameToken, allocator) catch null;
        operationName = name;
    }

    const variablesNodes = try parseVariableDefinition(parser, tokens, allocator);
    const directivesNodes = try parseDirectives(parser, tokens, allocator);
    const selectionSetNode = try parseSelectionSet(parser, tokens, allocator);

    return OperationDefinition{
        .allocator = allocator,
        .directives = directivesNodes,
        .name = operationName,
        .operation = operationType,
        .selectionSet = selectionSetNode,
        .variableDefinitions = variablesNodes,
    };
}
