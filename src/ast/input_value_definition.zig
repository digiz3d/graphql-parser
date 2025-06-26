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

pub fn parseInputValueDefinitions(parser: *Parser, isInputObjectTypeDefinition: bool) ParseError![]InputValueDefinition {
    const beginToken = if (isInputObjectTypeDefinition) Token.Tag.punct_brace_left else Token.Tag.punct_paren_left;
    const endToken = if (isInputObjectTypeDefinition) Token.Tag.punct_brace_right else Token.Tag.punct_paren_right;

    var inputValueDefinitions = ArrayList(InputValueDefinition).init(parser.allocator);

    var currentToken = parser.peekNextToken() orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != beginToken) {
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    _ = try parser.consumeToken(beginToken);

    while (currentToken.tag != endToken) : (currentToken = parser.peekNextToken() orelse
        return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
    {
        const description = try parseOptionalDescription(parser);
        const nameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;

        const name = try parser.getTokenValue(nameToken);
        errdefer parser.allocator.free(name);
        _ = try parser.consumeToken(Token.Tag.punct_colon);

        const value = try parseType(parser);

        var defaultValue: ?InputValue = null;
        if (parser.peekNextToken()) |nextToken| {
            if (nextToken.tag == Token.Tag.punct_equal) {
                _ = try parser.consumeToken(Token.Tag.punct_equal);
                defaultValue = try parseInputValue(parser, false);
            }
        }

        const directives = try parseDirectives(parser);

        const inputValueDefinition = InputValueDefinition{
            .allocator = parser.allocator,
            .description = description,
            .name = name,
            .value = value,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        inputValueDefinitions.append(inputValueDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;
    }

    _ = try parser.consumeToken(endToken);

    return inputValueDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing input values definitions" {
    const buffer = "(id: ID, value: String)";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const arguments = try parseInputValueDefinitions(&parser, false);
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
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const arguments = try parseInputValueDefinitions(&parser, false);
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
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const arguments = parseInputValueDefinitions(&parser, false);
    try testing.expectError(ParseError.ExpectedName, arguments);
}

test "parsing input value definitions with unexpected token from input object type definition" {
    const buffer = "{ $id: ID, value: String! }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const arguments = parseInputValueDefinitions(&parser, true);
    try testing.expectError(ParseError.ExpectedName, arguments);
}
