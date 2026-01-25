const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseNamedType = @import("type.zig").parseNamedType;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const UnionTypeExtension = @import("union_type_extension.zig").UnionTypeExtension;

pub const UnionTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    types: []Type,
    directives: []Directive,

    _is_merge_result: bool = false,

    pub fn deinit(self: UnionTypeDefinition) void {
        if (self._is_merge_result) {
            self.allocator.free(self.types);
            self.allocator.free(self.directives);
            return;
        }
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.types) |t| {
            t.deinit();
        }
        self.allocator.free(self.types);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }

    pub fn fromExtension(ext: UnionTypeExtension) UnionTypeDefinition {
        return UnionTypeDefinition{
            .allocator = ext.allocator,
            .name = ext.name,
            .description = null,
            .types = ext.types,
            .directives = ext.directives,
            ._is_merge_result = true,
        };
    }
};

pub fn parseUnionTypeDefinition(parser: *Parser) ParseError!UnionTypeDefinition {
    const description = try parseOptionalDescription(parser);
    try parser.consumeSpecificIdentifier("union");
    const unionNameToken = try parser.consumeToken(Token.Tag.identifier);
    const unionName = try parser.getTokenValue(unionNameToken);
    errdefer parser.allocator.free(unionName);

    const directivesNodes = try parseDirectives(parser);

    var types: ArrayList(Type) = .empty;
    errdefer {
        for (types.items) |t| {
            t.deinit();
        }
        types.deinit(parser.allocator);
    }

    const equalToken = parser.peekNextToken() orelse return ParseError.EmptyTokenList;
    if (equalToken.tag == Token.Tag.punct_equal) {
        _ = try parser.consumeToken(Token.Tag.punct_equal);
        while (true) {
            const t = try parseNamedType(parser, false);
            types.append(parser.allocator, t) catch return ParseError.UnexpectedMemoryError;
            const pipeToken = parser.peekNextToken() orelse break;
            if (pipeToken.tag != Token.Tag.punct_pipe) {
                break;
            }

            _ = try parser.consumeToken(Token.Tag.punct_pipe);
        }
    }

    return UnionTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .name = unionName,
        .types = types.toOwnedSlice(parser.allocator) catch return ParseError.UnexpectedMemoryError,
        .directives = directivesNodes,
    };
}

test "parse union type definition" {
    try runTest(
        "union TheUnion = Lol1 | Lol2",
        .{ .len = 2 },
    );
}

test "must not have non-null symbols" {
    try runTest(
        "union TheUnion = Lol1!",
        .{ .parseError = ParseError.UnexpectedExclamationMark },
    );
    try runTest(
        "union TheUnion = Lol1! | Lol2",
        .{ .parseError = ParseError.UnexpectedExclamationMark },
    );
    try runTest(
        "union TheUnion = Lol1 | Lol2!",
        .{ .parseError = ParseError.UnexpectedExclamationMark },
    );
}

test "wrong double pipe" {
    try runTest(
        "union TheUnion = Lol1 || Lol2",
        .{ .parseError = ParseError.ExpectedName },
    );
}

fn runTest(buffer: [:0]const u8, expectedLenOrError: union(enum) {
    len: usize,
    parseError: ParseError,
}) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    switch (expectedLenOrError) {
        .parseError => |expectedError| {
            const unionTypeDefinition = parseUnionTypeDefinition(&parser);
            try testing.expectError(expectedError, unionTypeDefinition);
        },
        .len => |length| {
            const unionTypeDefinition = try parseUnionTypeDefinition(&parser);
            defer unionTypeDefinition.deinit();

            try testing.expectEqual(length, unionTypeDefinition.types.len);
        },
    }
}
