const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseNamedType = @import("type.zig").parseNamedType;

const parseDirectives = @import("directive.zig").parseDirectives;

pub const UnionTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,
    types: []Type,

    pub fn deinit(self: UnionTypeExtension) void {
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
        for (self.types) |t| {
            t.deinit();
        }
        self.allocator.free(self.types);
    }
};

pub fn parseUnionTypeExtension(parser: *Parser) ParseError!UnionTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("union");

    const nameToken = try parser.consumeToken(Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);

    var types = ArrayList(Type).init(parser.allocator);
    errdefer {
        for (types.items) |t| {
            t.deinit();
        }
        types.deinit();
    }

    const equalToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    if (equalToken.tag == Token.Tag.punct_equal) {
        _ = try parser.consumeToken(Token.Tag.punct_equal);
        while (true) {
            const t = try parseNamedType(parser, false);
            types.append(t) catch return ParseError.UnexpectedMemoryError;
            const pipeToken = parser.peekNextToken() orelse break;
            if (pipeToken.tag != Token.Tag.punct_pipe) {
                break;
            }

            _ = try parser.consumeToken(Token.Tag.punct_pipe);
        }
    }

    return UnionTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .directives = directives,
        .types = types.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
}

test "parseUnionTypeExtension" {
    try runTest(
        \\extend union SomeUnion = NewType | AnotherType
    , 2);
}

test "parseUnionTypeExtension with directives" {
    try runTest(
        \\extend union SomeUnion @someDirective = NewType
    , 1);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const unionTypeExtension = try parseUnionTypeExtension(&parser);
    defer unionTypeExtension.deinit();

    try testing.expectEqual(len, unionTypeExtension.types.len);
}
