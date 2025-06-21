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

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
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

    pub fn printAST(self: ObjectTypeExtension, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ObjectTypeExtension\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  interfaces: {d}\n", .{ spaces, self.interfaces.len });
        for (self.interfaces) |interface| {
            interface.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }
};

pub fn parseObjectTypeExtension(parser: *Parser, tokens: []Token) ParseError!ObjectTypeExtension {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList; // "extend"
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList; // "type"

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const interfaces = try parseInterfaces(parser, tokens);
    const directives = try parseDirectives(parser, tokens);

    const leftBraceToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (leftBraceToken.tag != Token.Tag.punct_brace_left) {
        return ParseError.ExpectedBracketLeft;
    }

    var fields = ArrayList(FieldDefinition).init(parser.allocator);

    var nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    while (nextToken.tag != Token.Tag.punct_brace_right) {
        const fieldDefinition = try parseFieldDefinition(parser, tokens);
        fields.append(fieldDefinition) catch return ParseError.UnexpectedMemoryError;
        nextToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    }
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const objectTypeExtension = try parseObjectTypeExtension(&parser, tokens);
    defer objectTypeExtension.deinit();

    try testing.expectEqual(len, objectTypeExtension.fields.len);
}
