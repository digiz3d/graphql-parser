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
const Type = @import("type.zig").Type;
const parseType = @import("type.zig").parseType;
const InputValue = @import("input_value.zig").InputValue;
const parseInputValue = @import("input_value.zig").parseInputValue;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;

pub const InputValueDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    value: Type,
    defaultValue: ?InputValue,
    directives: []Directive,

    pub fn printAST(self: InputValueDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- InputValueDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        if (self.description != null) {
            std.debug.print("{s}  description: {s}\n", .{ spaces, newLineToBackslashN(self.allocator, self.description.?) });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        const value = self.value.getPrintableString(self.allocator);
        defer self.allocator.free(value);
        std.debug.print("{s}  value = {s}\n", .{ spaces, value });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: InputValueDefinition) void {
        self.allocator.free(self.name);
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.value.deinit();
        if (self.defaultValue != null) {
            self.defaultValue.?.deinit(self.allocator);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseInputValueDefinitions(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]InputValueDefinition {
    var inputValueDefinitions = ArrayList(InputValueDefinition).init(allocator);

    var currentToken = parser.peekNextToken(tokens) orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != Token.Tag.punct_paren_left) {
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    // consume the left parenthesis
    _ = parser.consumeNextToken(tokens) orelse return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = parser.peekNextToken(tokens) orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
    {
        const description = try parseOptionalDescription(parser, tokens, allocator);
        const nameToken = parser.consumeNextToken(tokens) orelse return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (nameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;

        const name = try parser.getTokenValue(nameToken, allocator);
        errdefer allocator.free(name);
        const colonToken = parser.consumeNextToken(tokens) orelse return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (colonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

        const value = try parseType(parser, tokens, allocator);

        var defaultValue: ?InputValue = null;
        if (parser.peekNextToken(tokens)) |nextToken| {
            if (nextToken.tag == Token.Tag.punct_equal) {
                _ = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
                defaultValue = try parseInputValue(parser, tokens, allocator, false);
            }
        }

        const directives = try parseDirectives(parser, tokens, allocator);

        const inputValueDefinition = InputValueDefinition{
            .allocator = allocator,
            .description = description,
            .name = name,
            .value = value,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        inputValueDefinitions.append(inputValueDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    // consume the right parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis;

    return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing input values definitions" {
    const buffer = "(id: ID, value: String)";
    const arguments = try runTest(buffer, testing.allocator);
    defer {
        for (arguments) |argument| {
            argument.deinit();
        }
        testing.allocator.free(arguments);
    }

    try testing.expectEqual(2, arguments.len);
}

test "parsing input value definition with description, directive" {
    const buffer = "(\"some description\" arg: Ok = \"default\" @someDirective, arg2: Ok)";
    const arguments = try runTest(buffer, testing.allocator);
    defer {
        for (arguments) |argument| {
            argument.deinit();
        }
        testing.allocator.free(arguments);
    }

    try testing.expectEqual(2, arguments.len);
    try testing.expectEqualStrings("\"some description\"", arguments[0].description.?);
    try testing.expectEqualStrings("arg", arguments[0].name);
    try testing.expectEqualStrings("Ok", arguments[0].value.namedType.name);
    try testing.expectEqualStrings("\"default\"", arguments[0].defaultValue.?.string_value.value);
    try testing.expectEqualStrings("someDirective", arguments[0].directives[0].name);
    try testing.expectEqualStrings("arg2", arguments[1].name);
    try testing.expectEqualStrings("Ok", arguments[1].value.namedType.name);
    try testing.expectEqual(null, arguments[1].defaultValue);
}

test "parsing input value definitions with unexpected token" {
    const buffer = "($id: ID, value: String)";
    const arguments = runTest(buffer, testing.allocator);
    try testing.expectError(ParseError.ExpectedName, arguments);
}

fn runTest(buffer: [:0]const u8, testing_allocator: Allocator) ![]InputValueDefinition {
    var parser = Parser.init();
    var tokenizer = Tokenizer.init(testing_allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing_allocator.free(tokens);

    return parseInputValueDefinitions(&parser, tokens, testing_allocator);
}
