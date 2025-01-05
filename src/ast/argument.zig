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

    pub fn printAST(self: Argument, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- Argument\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        const value = self.value.getPrintableString(self.allocator);
        defer self.allocator.free(value);
        std.debug.print("{s}  value = {s}\n", .{ spaces, value });
    }

    pub fn deinit(self: Argument) void {
        self.allocator.free(self.name);
        self.value.deinit(self.allocator);
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
        if (argumentNameToken.tag != Token.Tag.identifier) return arguments.toOwnedSlice() catch return ParseError.ExpectedName;

        const argumentName = try parser.getTokenValue(argumentNameToken, allocator);
        const colonToken = parser.consumeNextToken(tokens) orelse return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (colonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

        const argumentValue = try parseInputValue(parser, tokens, allocator);

        const argument = Argument{
            .allocator = allocator,
            .name = argumentName,
            .value = argumentValue,
        };
        arguments.append(argument) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    // consume the right parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis;

    return arguments.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing arguments" {
    var parser = Parser.init();
    const buffer = "(id: 123, value: $var)";

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const arguments = try parseArguments(&parser, tokens, testing.allocator);
    defer {
        for (arguments) |argument| {
            argument.deinit();
        }
        testing.allocator.free(arguments);
    }

    try testing.expectEqual(2, arguments.len);
}
