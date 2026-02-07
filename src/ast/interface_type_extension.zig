const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parse.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parse.zig").ParseError;

const Interface = @import("interface.zig").Interface;
const Directive = @import("directive.zig").Directive;
const FieldDefinition = @import("field_definition.zig").FieldDefinition;

const parseInterfaces = @import("interface.zig").parseInterfaces;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseFieldDefinition = @import("field_definition.zig").parseFieldDefinition;

pub const InterfaceTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    interfaces: []Interface,
    directives: []Directive,
    fields: []FieldDefinition,

    pub fn deinit(self: InterfaceTypeExtension) void {
        self.allocator.free(self.name);
        for (self.interfaces) |interface| {
            interface.deinit();
        }
        self.allocator.free(self.interfaces);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
        for (self.fields) |field| {
            field.deinit();
        }
        self.allocator.free(self.fields);
    }
};

pub fn parseInterfaceTypeExtension(parser: *Parser) ParseError!InterfaceTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("interface");

    const nameToken = try parser.consumeToken(Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const interfaces = try parseInterfaces(parser);
    const directives = try parseDirectives(parser);

    _ = try parser.consumeToken(Token.Tag.punct_brace_left);

    var fields: ArrayList(FieldDefinition) = .empty;

    var nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const fieldDefinition = try parseFieldDefinition(parser);
        fields.append(parser.allocator, fieldDefinition) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    }
    _ = try parser.consumeToken(Token.Tag.punct_brace_right);

    return InterfaceTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
    };
}

test "parseInterfaceTypeExtension" {
    try runTest(
        \\extend interface SomeInterface implements OtherInterface @lol {
        \\ "new field desc"
        \\ newField: String
        \\}
    , 1);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const interfaceTypeExtension = try parseInterfaceTypeExtension(&parser);
    defer interfaceTypeExtension.deinit();

    try testing.expectEqual(len, interfaceTypeExtension.fields.len);
    const newField = interfaceTypeExtension.fields[0];
    try testing.expectEqualStrings("\"new field desc\"", newField.description.?);
    try testing.expectEqualStrings("newField", newField.name);
    try testing.expectEqual(0, newField.arguments.len);
    try testing.expectEqual(0, newField.directives.len);
}
