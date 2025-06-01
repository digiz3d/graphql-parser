const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const d = @import("directive.zig");
const parseDirectives = d.parseDirectives;
const Directive = d.Directive;

const input = @import("input_value.zig");
const InputValue = input.InputValue;
const parseInputValue = input.parseInputValue;

const ty = @import("type.zig");
const Type = ty.Type;
const parseType = ty.parseType;

pub const VariableDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    type: Type,
    defaultValue: ?InputValue,
    directives: []Directive,

    pub fn printAST(self: VariableDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- VariableDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  type\n", .{spaces});
        self.type.printAST(indent, self.allocator);
        if (self.defaultValue != null) {
            const value = self.defaultValue.?.getPrintableString(self.allocator);
            defer self.allocator.free(value);
            std.debug.print("{s}  defaultValue = {s}\n", .{ spaces, value });
        } else {
            std.debug.print("{s}  defaultValue = null\n", .{spaces});
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: VariableDefinition) void {
        self.allocator.free(self.name);
        self.type.deinit();
        if (self.defaultValue != null) {
            self.defaultValue.?.deinit(self.allocator);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseVariableDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]VariableDefinition {
    var variableDefinitions = ArrayList(VariableDefinition).init(allocator);

    var currentToken = parser.peekNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != Token.Tag.punct_paren_left) return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    // consume the left parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedLeftParenthesis;

    while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError) {
        const variableDollarToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedDollar;
        if (variableDollarToken.tag != Token.Tag.punct_dollar) return ParseError.ExpectedDollar;

        const variableNameToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
        if (variableNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
        const variableName = try parser.getTokenValue(variableNameToken, allocator);
        errdefer allocator.free(variableName);

        const variableColonToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedColon;

        if (variableColonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

        const nextToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;

        if (nextToken.tag == Token.Tag.punct_dollar) return ParseError.ExpectedName;

        const variableType = try parseType(parser, tokens, allocator);
        errdefer variableType.deinit();

        const defaultValueToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;

        var defaultValue: ?input.InputValue = null;
        if (defaultValueToken.tag == Token.Tag.punct_equal) {
            _ = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            defaultValue = try parseInputValue(parser, tokens, allocator, false);
        }

        const directives = try parseDirectives(parser, tokens, allocator);

        const variableDefinition = VariableDefinition{
            .allocator = allocator,
            .name = variableName,
            .type = variableType,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        variableDefinitions.append(variableDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    // consume the right parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis;

    return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "empty" {
    try runTest("", .{ .len = 0 });
}

test "variables definitions" {
    try runTest("($name: String, $id: Int)", .{ .len = 2 });
}

test "NonNull variables definitions" {
    try runTest("($name: String!, $id: Int!)", .{ .len = 2 });
}

test "missing $" {
    try runTest("(name: String!)", .{ .parseError = ParseError.ExpectedDollar });
}

test "expected name not variable" {
    try runTest("($name: $oops!)", .{ .parseError = ParseError.ExpectedName });
}

test "default value" {
    try runTest("($name: String = \"default\")", .{ .len = 1 });
}

test "default value not variable" {
    try runTest("($name: String = $default)", .{ .parseError = ParseError.UnexpectedToken });
}

fn runTest(buffer: [:0]const u8, expectedLenOrError: union(enum) {
    len: usize,
    parseError: ParseError,
}) !void {
    var parser = Parser.init();

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    switch (expectedLenOrError) {
        .parseError => |expectedError| {
            const variableDefinitions = parseVariableDefinition(&parser, tokens, testing.allocator);
            try testing.expectError(expectedError, variableDefinitions);
            return;
        },
        .len => |length| {
            const variableDefinitions = try parseVariableDefinition(&parser, tokens, testing.allocator);
            defer {
                for (variableDefinitions) |variableDefinition| {
                    variableDefinition.deinit();
                }
                testing.allocator.free(variableDefinitions);
            }
            try testing.expectEqual(length, variableDefinitions.len);
        },
    }
}
