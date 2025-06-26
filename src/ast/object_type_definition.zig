const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const parserImport = @import("../parser.zig");
const Parser = parserImport.Parser;
const ParseError = parserImport.ParseError;
const parseDirectives = @import("directive.zig").parseDirectives;
const Directive = @import("directive.zig").Directive;
const FieldDefinition = @import("field_definition.zig").FieldDefinition;
const parseFieldDefinition = @import("field_definition.zig").parseFieldDefinition;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

const Interface = @import("interface.zig").Interface;
const parseInterfaces = @import("interface.zig").parseInterfaces;

pub const ObjectTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    interfaces: []Interface,
    directives: []Directive,
    fields: []FieldDefinition,

    pub fn deinit(self: ObjectTypeDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.interfaces) |interface| {
            interface.deinit();
        }
        self.allocator.free(self.interfaces);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        for (self.fields) |item| {
            item.deinit();
        }
        self.allocator.free(self.fields);
    }
};

pub fn parseObjectTypeDefinition(parser: *Parser) ParseError!ObjectTypeDefinition {
    const description = try parseOptionalDescription(parser);
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

    const objectTypeDefinition = ObjectTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .interfaces = interfaces,
        .directives = directives,
        .name = name,
        .fields = fields.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
    return objectTypeDefinition;
}

test "parseObjectTypeDefinition" {
    try runTest(
        \\type Query @lol {
        \\ ok(id:String): Boolean! @lol
        \\}
    , 1);
}
test "parseObjectTypeDefinition with two fields" {
    try runTest(
        \\type Query {
        \\ ok: Boolean!
        \\ ok2: Boolean
        \\}
    , 2);
}
test "parseObjectTypeDefinition with two fields that implements interface" {
    try runTest(
        \\type Hi implements A & B @lol {
        \\ ok: Boolean!
        \\ ok2: Boolean
        \\}
    , 2);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const objectTypeDefinition = try parseObjectTypeDefinition(&parser);
    defer objectTypeDefinition.deinit();

    try testing.expectEqual(len, objectTypeDefinition.fields.len);
}
