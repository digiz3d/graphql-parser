const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parserImport = @import("../parser.zig");
const Parser = parserImport.Parser;
const ParseError = parserImport.ParseError;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const InputValueDefinition = @import("input_value_definition.zig").InputValueDefinition;
const parseInputValueDefinitions = @import("input_value_definition.zig").parseInputValueDefinitions;
const parseDirectives = @import("directive.zig").parseDirectives;
const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseType = @import("type.zig").parseType;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const FieldDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    type: Type,
    arguments: []InputValueDefinition,
    directives: []Directive,

    pub fn printAST(self: FieldDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FieldDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: FieldDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        self.type.deinit();
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseFieldDefinition(parser: *Parser, tokens: []Token) !FieldDefinition {
    const description = try parseOptionalDescription(parser, tokens);

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const name = try parser.getTokenValue(nameToken);
    defer parser.allocator.free(name);

    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const arguments = try parseInputValueDefinitions(parser, tokens, false);

    const colonToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (colonToken.tag != Token.Tag.punct_colon) {
        return ParseError.ExpectedColon;
    }

    const namedType = try parseType(parser, tokens);

    const directives = try parseDirectives(parser, tokens);

    const fieldDefinition = FieldDefinition{
        .allocator = parser.allocator,
        .description = description,
        .name = parser.allocator.dupe(u8, name) catch return ParseError.UnexpectedMemoryError,
        .type = namedType,
        .arguments = arguments,
        .directives = directives,
    };

    return fieldDefinition;
}

test "parsing simple field definition" {
    const buffer = "name: String";
    const field = try runTest(buffer, testing.allocator);
    defer field.deinit();

    try testing.expectEqualStrings("name", field.name);
    try testing.expectEqual(null, field.description);
    try testing.expectEqual(@as(usize, 0), field.arguments.len);
    try testing.expectEqual(@as(usize, 0), field.directives.len);
}

test "parsing field definition with description" {
    const buffer = "\"field description\" name: String";
    const field = try runTest(buffer, testing.allocator);
    defer field.deinit();

    try testing.expectEqualStrings("name", field.name);
    try testing.expectEqualStrings("\"field description\"", field.description.?);
    try testing.expectEqual(@as(usize, 0), field.arguments.len);
    try testing.expectEqual(@as(usize, 0), field.directives.len);
}

test "parsing field definition with arguments" {
    const buffer = "name(id: ID!, value: String = \"default\"): String";
    const field = try runTest(buffer, testing.allocator);
    defer field.deinit();

    try testing.expectEqualStrings("name", field.name);
    try testing.expectEqual(@as(usize, 2), field.arguments.len);
    try testing.expectEqual(@as(usize, 0), field.directives.len);
}

test "parsing field definition with directives" {
    const buffer = "name: String @deprecated(reason: \"no longer used\")";
    const field = try runTest(buffer, testing.allocator);
    defer field.deinit();

    try testing.expectEqualStrings("name", field.name);
    try testing.expectEqual(@as(usize, 0), field.arguments.len);
    try testing.expectEqual(@as(usize, 1), field.directives.len);
}

test "parsing field definition with unexpected token" {
    const buffer = "123: String";
    const field = runTest(buffer, testing.allocator);
    try testing.expectError(ParseError.ExpectedName, field);
}

fn runTest(buffer: [:0]const u8, testing_allocator: Allocator) !FieldDefinition {
    var parser = Parser.init(testing.allocator);
    var tokenizer = Tokenizer.init(testing_allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing_allocator.free(tokens);

    return parseFieldDefinition(&parser, tokens);
}
