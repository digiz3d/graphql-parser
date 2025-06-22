const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
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

    pub fn printAST(self: EnumTypeExtension, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- EnumTypeExtension\n", .{spaces});
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
        std.debug.print("{s}  values: {d}\n", .{ spaces, self.values.len });
        for (self.values) |value| {
            value.printAST(indent + 1);
        }
    }
};

pub fn parseEnumTypeExtension(parser: *Parser, tokens: []Token) ParseError!EnumTypeExtension {
    try parser.consumeSpecificIdentifier(tokens, "extend");
    try parser.consumeSpecificIdentifier(tokens, "enum");

    const nameToken = parser.consumeToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);

    _ = try parser.consumeToken(tokens, Token.Tag.punct_brace_left);

    var values = ArrayList(EnumValueDefinition).init(parser.allocator);
    errdefer {
        for (values.items) |value| {
            value.deinit();
        }
        values.deinit();
    }

    var nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const value = try parseEnumValueDefinition(parser, tokens);
        values.append(value) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    }

    _ = try parser.consumeToken(tokens, Token.Tag.punct_brace_right);

    return EnumTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .directives = directives,
        .values = values.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const enumTypeExtension = try parseEnumTypeExtension(&parser, tokens);
    defer enumTypeExtension.deinit();

    try testing.expectEqual(valuesCount, enumTypeExtension.values.len);
    try testing.expectEqual(directivesCount, enumTypeExtension.directives.len);
}
