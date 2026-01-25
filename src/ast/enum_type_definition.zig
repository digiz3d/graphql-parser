const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const EnumValueDefinition = @import("enum_value_definition.zig").EnumValueDefinition;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseEnumValueDefinition = @import("enum_value_definition.zig").parseEnumValueDefinition;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const EnumTypeExtension = @import("enum_type_extension.zig").EnumTypeExtension;

pub const EnumTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,
    values: []EnumValueDefinition,

    pub fn deinit(self: EnumTypeDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.values) |value| {
            value.deinit();
        }
        self.allocator.free(self.values);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }

    pub fn fromExtension(ext: EnumTypeExtension) EnumTypeDefinition {
        return EnumTypeDefinition{
            .allocator = ext.allocator,
            .name = ext.name,
            .directives = ext.directives,
            .values = ext.values,
        };
    }
};

pub fn parseEnumTypeDefinition(parser: *Parser) ParseError!EnumTypeDefinition {
    const description = try parseOptionalDescription(parser);
    try parser.consumeSpecificIdentifier("enum");
    const nameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);

    var values: ArrayList(EnumValueDefinition) = .empty;
    errdefer {
        for (values.items) |value| {
            value.deinit();
        }
        values.deinit(parser.allocator);
    }

    _ = try parser.consumeToken(Token.Tag.punct_brace_left);

    var nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const value = try parseEnumValueDefinition(parser);
        values.append(parser.allocator, value) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    }

    _ = try parser.consumeToken(Token.Tag.punct_brace_right);

    return EnumTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .directives = directives,
        .name = name,
        .values = values.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
    };
}

test "parseEnumTypeDefinition without directives" {
    try runTest(
        \\enum SomeEum  {
        \\  SOME_VALUE 
        \\  SOME_OTHER_VALUE
        \\}
    , 2, 0);
}
test "parseEnumTypeDefinition with directives" {
    try runTest(
        \\enum SomeEum @ok1 {
        \\  SOME_VALUE @ok3
        \\  SOME_OTHER_VALUE @ok4
        \\}
    , 2, 1);
}

fn runTest(buffer: [:0]const u8, valuesCount: usize, directivesCount: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const enumTypeDefinition = try parseEnumTypeDefinition(&parser);
    defer enumTypeDefinition.deinit();

    try testing.expectEqual(valuesCount, enumTypeDefinition.values.len);
    try testing.expectEqual(directivesCount, enumTypeDefinition.directives.len);
}
