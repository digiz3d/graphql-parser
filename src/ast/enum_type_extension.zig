const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parse.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parse.zig").ParseError;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const EnumValueDefinition = @import("enum_value_definition.zig").EnumValueDefinition;
const parseEnumValueDefinition = @import("enum_value_definition.zig").parseEnumValueDefinition;

pub const EnumTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,
    values: []EnumValueDefinition,

    pub fn deinit(self: EnumTypeExtension) void {
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
        for (self.values) |value| {
            value.deinit();
        }
        self.allocator.free(self.values);
    }
};

pub fn parseEnumTypeExtension(parser: *Parser) ParseError!EnumTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("enum");

    const nameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);

    _ = try parser.consumeToken(Token.Tag.punct_brace_left);

    var values: ArrayList(EnumValueDefinition) = .empty;
    errdefer {
        for (values.items) |value| {
            value.deinit();
        }
        values.deinit(parser.allocator);
    }

    var nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const value = try parseEnumValueDefinition(parser);
        values.append(parser.allocator, value) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    }

    _ = try parser.consumeToken(Token.Tag.punct_brace_right);

    return EnumTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .directives = directives,
        .values = values.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
    };
}

test "parseEnumTypeExtension" {
    try runTest(
        \\extend enum SomeEnum2 @ok1 {
        \\  "enum new value desc"
        \\  SOME_NEW_VALUE @ok4
        \\}
    , 1, 1);
}

fn runTest(buffer: [:0]const u8, valuesCount: usize, directivesCount: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const enumTypeExtension = try parseEnumTypeExtension(&parser);
    defer enumTypeExtension.deinit();

    try testing.expectEqual(valuesCount, enumTypeExtension.values.len);
    try testing.expectEqual(directivesCount, enumTypeExtension.directives.len);
}
