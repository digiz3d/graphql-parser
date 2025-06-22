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
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parseEnumValueDefinition = @import("enum_value_definition.zig").parseEnumValueDefinition;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub const EnumTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,
    values: []EnumValueDefinition,

    pub fn printAST(self: EnumTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- EnumTypeDefinition\n", .{spaces});
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
        std.debug.print("{s}  values: {d}\n", .{ spaces, self.values.len });
        for (self.values) |value| {
            value.printAST(indent + 1);
        }
    }

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
};

pub fn parseEnumTypeDefinition(parser: *Parser, tokens: []Token) ParseError!EnumTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    try parser.consumeSpecificIdentifier(tokens, "enum");
    const nameToken = parser.consumeSpecificToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);

    var values = ArrayList(EnumValueDefinition).init(parser.allocator);
    errdefer {
        for (values.items) |value| {
            value.deinit();
        }
        values.deinit();
    }

    _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_brace_left);

    var nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const value = try parseEnumValueDefinition(parser, tokens);
        values.append(value) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    }

    _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_brace_right);

    return EnumTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .directives = directives,
        .name = name,
        .values = values.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const enumTypeDefinition = try parseEnumTypeDefinition(&parser, tokens);
    defer enumTypeDefinition.deinit();

    try testing.expectEqual(valuesCount, enumTypeDefinition.values.len);
    try testing.expectEqual(directivesCount, enumTypeDefinition.directives.len);
}
