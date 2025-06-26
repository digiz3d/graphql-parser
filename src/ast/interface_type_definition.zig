const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const FieldDefinition = @import("field_definition.zig").FieldDefinition;
const Directive = @import("directive.zig").Directive;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const parseFieldDefinition = @import("field_definition.zig").parseFieldDefinition;
const parseDirectives = @import("directive.zig").parseDirectives;

const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const strEq = @import("../utils/utils.zig").strEq;

const Interface = @import("interface.zig").Interface;
const parseInterfaces = @import("interface.zig").parseInterfaces;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;

pub const InterfaceTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    interfaces: []Interface,
    fields: []FieldDefinition,
    directives: []Directive,

    pub fn deinit(self: InterfaceTypeDefinition) void {
        self.allocator.free(self.name);
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        for (self.interfaces) |interface| {
            interface.deinit();
        }
        self.allocator.free(self.interfaces);
        for (self.fields) |field| {
            field.deinit();
        }
        self.allocator.free(self.fields);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseInterfaceTypeDefinition(parser: *Parser) ParseError!InterfaceTypeDefinition {
    const description = try parseOptionalDescription(parser);

    try parser.consumeSpecificIdentifier("interface");

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

    return InterfaceTypeDefinition{
        .allocator = parser.allocator,
        .name = name,
        .description = description,
        .interfaces = interfaces,
        .fields = fields.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        .directives = directives,
    };
}

test "parseInterfaceTypeDefinition simple" {
    const buffer =
        \\ interface X {
        \\   id: ID!
        \\ }
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const interfaceTypeDefinition = try parseInterfaceTypeDefinition(&parser);
    defer interfaceTypeDefinition.deinit();

    try std.testing.expectEqualStrings("X", interfaceTypeDefinition.name);
    try std.testing.expectEqualStrings("id", interfaceTypeDefinition.fields[0].name);
}

test "parseInterfaceTypeDefinition composed of other interfaces" {
    const buffer =
        \\ interface A implements B & C @lol {
        \\   id: ID!
        \\ }
    ;
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const interfaceTypeDefinition = try parseInterfaceTypeDefinition(&parser);
    defer interfaceTypeDefinition.deinit();

    try std.testing.expectEqualStrings("A", interfaceTypeDefinition.name);
    try std.testing.expectEqualStrings("B", interfaceTypeDefinition.interfaces[0].type.namedType.name);
    try std.testing.expectEqualStrings("C", interfaceTypeDefinition.interfaces[1].type.namedType.name);
    try std.testing.expectEqualStrings("id", interfaceTypeDefinition.fields[0].name);
}
