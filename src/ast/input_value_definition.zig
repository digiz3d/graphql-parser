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
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
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
        if (self.defaultValue != null) {
            std.debug.print("{s}  defaultValue: {s}\n", .{ spaces, self.defaultValue.?.getPrintableString(self.allocator) });
        } else {
            std.debug.print("{s}  defaultValue: null\n", .{spaces});
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

pub fn parseInputValueDefinitions(parser: *Parser, tokens: []Token, isInputObjectTypeDefinition: bool) ParseError![]InputValueDefinition {
    const beginToken = if (isInputObjectTypeDefinition) Token.Tag.punct_brace_left else Token.Tag.punct_paren_left;
    const endToken = if (isInputObjectTypeDefinition) Token.Tag.punct_brace_right else Token.Tag.punct_paren_right;

    var inputValueDefinitions = ArrayList(InputValueDefinition).init(parser.allocator);

    var currentToken = parser.peekNextToken(tokens) orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != beginToken) {
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    _ = try parser.consumeSpecificToken(tokens, beginToken);

    while (currentToken.tag != endToken) : (currentToken = parser.peekNextToken(tokens) orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
    {
        const description = try parseOptionalDescription(parser, tokens);
        const nameToken = parser.consumeSpecificToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;

        const name = try parser.getTokenValue(nameToken);
        errdefer parser.allocator.free(name);
        _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_colon);

        const value = try parseType(parser, tokens);

        var defaultValue: ?InputValue = null;
        if (parser.peekNextToken(tokens)) |nextToken| {
            if (nextToken.tag == Token.Tag.punct_equal) {
                _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_equal);
                defaultValue = try parseInputValue(parser, tokens, false);
            }
        }

        const directives = try parseDirectives(parser, tokens);

        const inputValueDefinition = InputValueDefinition{
            .allocator = parser.allocator,
            .description = description,
            .name = name,
            .value = value,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        inputValueDefinitions.append(inputValueDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
    }

    _ = try parser.consumeSpecificToken(tokens, endToken);

    return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing input values definitions" {
    const buffer = "(id: ID, value: String)";
    const arguments = try runTest(buffer, false);
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
    const arguments = try runTest(buffer, false);
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
    const arguments = runTest(buffer, false);
    try testing.expectError(ParseError.ExpectedName, arguments);
}

test "parsing input value definitions with unexpected token from input object type definition" {
    const buffer = "{ $id: ID, value: String! }";
    const arguments = runTest(buffer, true);
    try testing.expectError(ParseError.ExpectedName, arguments);
}

fn runTest(buffer: [:0]const u8, isInputObjectTypeDefinition: bool) ![]InputValueDefinition {
    var parser = Parser.init(testing.allocator);
    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    return parseInputValueDefinitions(&parser, tokens, isInputObjectTypeDefinition);
}
