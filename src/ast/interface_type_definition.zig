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

    pub fn printAST(self: InterfaceTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        std.debug.print("{s}- InterfaceTypeDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  description = {?s}\n", .{ spaces, self.description });
        std.debug.print("{s}  interfaces: {d}\n", .{ spaces, self.interfaces.len });
        for (self.interfaces) |interface| {
            interface.printAST(indent + 1);
        }
        std.debug.print("{s}  fields: {d}\n", .{ spaces, self.fields.len });
        for (self.fields) |field| {
            field.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

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

pub fn parseInterfaceTypeDefinition(parser: *Parser, tokens: []Token) ParseError!InterfaceTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);

    const interfaceToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const interfaceStr = try parser.getTokenValue(interfaceToken);
    defer parser.allocator.free(interfaceStr);
    if (interfaceToken.tag != Token.Tag.identifier or !strEq(interfaceStr, "interface")) {
        return ParseError.UnexpectedToken;
    }

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
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
    const interfaceTypeDefinition = try runTest(buffer);
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
    const interfaceTypeDefinition = try runTest(buffer);
    defer interfaceTypeDefinition.deinit();

    try std.testing.expectEqualStrings("A", interfaceTypeDefinition.name);
    try std.testing.expectEqualStrings("B", interfaceTypeDefinition.interfaces[0].type.namedType.name);
    try std.testing.expectEqualStrings("C", interfaceTypeDefinition.interfaces[1].type.namedType.name);
    try std.testing.expectEqualStrings("id", interfaceTypeDefinition.fields[0].name);
}

fn runTest(buffer: [:0]const u8) !InterfaceTypeDefinition {
    var parser = Parser.init(std.testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const interfaceTypeDefinition = try parseInterfaceTypeDefinition(&parser, tokens);
    return interfaceTypeDefinition;
}
