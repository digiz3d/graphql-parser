const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Interface = @import("interface.zig").Interface;
const Directive = @import("directive.zig").Directive;
const FieldDefinition = @import("field_definition.zig").FieldDefinition;

const parseInterfaces = @import("interface.zig").parseInterfaces;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseFieldDefinition = @import("field_definition.zig").parseFieldDefinition;

pub const ObjectTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    interfaces: []Interface,
    directives: []Directive,
    fields: []FieldDefinition,

    pub fn deinit(self: ObjectTypeExtension) void {
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

pub fn parseObjectTypeExtension(parser: *Parser) ParseError!ObjectTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("type");

    const nameToken = try parser.consumeToken(Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const interfaces = try parseInterfaces(parser);
    const directives = try parseDirectives(parser);

    _ = try parser.consumeToken(Token.Tag.punct_brace_left);

    var fields = ArrayList(FieldDefinition).init(parser.allocator);

    var nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const fieldDefinition = try parseFieldDefinition(parser);
        fields.append(fieldDefinition) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    }
    _ = try parser.consumeToken(Token.Tag.punct_brace_right);

    return ObjectTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .interfaces = interfaces,
        .directives = directives,
        .fields = fields.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
}

test "parseObjectTypeDefinition" {
    try runTest(
        \\extend type Query @lol {
        \\ ok(id:String): Boolean! @lol
        \\}
    , 1);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const objectTypeExtension = try parseObjectTypeExtension(&parser);
    defer objectTypeExtension.deinit();

    try testing.expectEqual(len, objectTypeExtension.fields.len);
}
