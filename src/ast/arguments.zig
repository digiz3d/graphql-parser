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

const inputValue = @import("input_value.zig");
const InputValue = inputValue.InputValue;
const parseInputValue = inputValue.parseInputValue;

pub const Argument = struct {
    allocator: Allocator,
    name: []const u8,
    value: InputValue,
    defaultValue: ?InputValue,

    pub fn printAST(self: Argument, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- InputValueDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        const value = self.value.getPrintableString(self.allocator);
        defer self.allocator.free(value);
        std.debug.print("{s}  value = {s}\n", .{ spaces, value });
    }

    pub fn deinit(self: Argument) void {
        self.allocator.free(self.name);
        self.value.deinit(self.allocator);
        if (self.defaultValue != null) {
            self.defaultValue.?.deinit(self.allocator);
        }
    }
};

pub fn parseArguments(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]Argument {
    var arguments = ArrayList(Argument).init(allocator);

    var currentToken = parser.peekNextToken(tokens) orelse
        return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != Token.Tag.punct_paren_left) {
        return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    // consume the left parenthesis
    _ = parser.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = parser.peekNextToken(tokens) orelse
        return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
    {
        const argumentNameToken = parser.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (argumentNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;

        const argumentName = try parser.getTokenValue(argumentNameToken, allocator);
        errdefer allocator.free(argumentName);
        const colonToken = parser.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (colonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

        const argumentValue = try parseInputValue(parser, tokens, allocator, true);

        var defaultValue: ?InputValue = null;
        if (parser.peekNextToken(tokens)) |nextToken| {
            if (nextToken.tag == Token.Tag.punct_equal) {
                _ = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
                defaultValue = try parseInputValue(parser, tokens, allocator, true);
            }
        }

        const argument = Argument{
            .allocator = allocator,
            .name = argumentName,
            .value = argumentValue,
            .defaultValue = defaultValue,
        };
        arguments.append(argument) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    // consume the right parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis;

    return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing arguments" {
    const buffer = "(id: 123, value: $var)";
    const arguments = try runTest(buffer, testing.allocator);
    defer {
        for (arguments) |argument| {
            argument.deinit();
        }
        testing.allocator.free(arguments);
    }

    try testing.expectEqual(2, arguments.len);
}

test "parsing argument with default value" {
    const buffer = "(id: 123, value: $var = 456)";
    const arguments = try runTest(buffer, testing.allocator);
    defer {
        for (arguments) |argument| {
            argument.deinit();
        }
        testing.allocator.free(arguments);
    }

    try testing.expectEqual(2, arguments.len);
    try testing.expectEqual(null, arguments[0].defaultValue);
    try testing.expectEqual(InputValue{ .int_value = .{ .value = 456 } }, arguments[1].defaultValue.?);
}

test "parsing arguments with unexpected token" {
    const buffer = "($id: 123, value: $var)";
    const arguments = runTest(buffer, testing.allocator);
    try testing.expectError(ParseError.ExpectedName, arguments);
}

fn runTest(buffer: [:0]const u8, testing_allocator: Allocator) ![]Argument {
    var parser = Parser.init();
    var tokenizer = Tokenizer.init(testing_allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing_allocator.free(tokens);

    return parseArguments(&parser, tokens, testing_allocator);
}
