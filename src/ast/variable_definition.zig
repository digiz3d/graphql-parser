const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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

pub fn parseVariableDefinition(parser: *Parser) ParseError![]VariableDefinition {
    var variableDefinitions: ArrayList(VariableDefinition) = .empty;

    var currentToken = parser.peekNextToken() orelse return variableDefinitions.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError;
    if (currentToken.tag != Token.Tag.punct_paren_left) return variableDefinitions.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError;

    _ = try parser.consumeToken(Token.Tag.punct_paren_left);

    while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError) {
        _ = parser.consumeToken(Token.Tag.punct_dollar) catch return ParseError.ExpectedDollar;

        const variableNameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
        const variableName = try parser.getTokenValue(variableNameToken);
        errdefer parser.allocator.free(variableName);

        _ = parser.consumeToken(Token.Tag.punct_colon) catch return ParseError.ExpectedColon;

        const nextToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;

        if (nextToken.tag == Token.Tag.punct_dollar) return ParseError.ExpectedName;

        const variableType = try parseType(parser);
        errdefer variableType.deinit();

        const defaultValueToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;

        var defaultValue: ?input.InputValue = null;
        if (defaultValueToken.tag == Token.Tag.punct_equal) {
            _ = try parser.consumeToken(Token.Tag.punct_equal);
            defaultValue = try parseInputValue(parser, false);
        }

        const directives = try parseDirectives(parser);

        const variableDefinition = VariableDefinition{
            .allocator = parser.allocator,
            .name = variableName,
            .type = variableType,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        variableDefinitions.append(parser.allocator, variableDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;
    }

    _ = try parser.consumeToken(Token.Tag.punct_paren_right);

    return variableDefinitions.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError;
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
    try runTest("($name: String = $default)", .{ .parseError = ParseError.ExpectedName });
}

test "missing colon" {
    try runTest("($name String = $default)", .{ .parseError = ParseError.ExpectedColon });
}

fn runTest(buffer: [:0]const u8, expectedLenOrError: union(enum) {
    len: usize,
    parseError: ParseError,
}) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    switch (expectedLenOrError) {
        .parseError => |expectedError| {
            const variableDefinitions = parseVariableDefinition(&parser);
            try testing.expectError(expectedError, variableDefinitions);
            return;
        },
        .len => |length| {
            const variableDefinitions = try parseVariableDefinition(&parser);
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
