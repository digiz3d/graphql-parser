const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseNamedType = @import("type.zig").parseNamedType;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const UnionTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    types: []Type,
    directives: []Directive,

    pub fn printAST(self: UnionTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- UnionTypeDefinition\n", .{spaces});
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  types:\n", .{spaces});
        for (self.types) |t| {
            t.printAST(indent + 1, self.allocator);
        }
        std.debug.print("{s}  directives:\n", .{spaces});
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

    pub fn deinit(self: UnionTypeDefinition) void {
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
};

pub fn parseUnionTypeDefinition(parser: *Parser, tokens: []Token) ParseError!UnionTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const unionNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const unionName = try parser.getTokenValue(unionNameToken);
    errdefer parser.allocator.free(unionName);

    const directivesNodes = try parseDirectives(parser, tokens);

    var types = ArrayList(Type).init(parser.allocator);
    errdefer {
        for (types.items) |t| {
            t.deinit();
        }
        types.deinit();
    }

    const equalToken = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (equalToken.tag == Token.Tag.punct_equal) {
        _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        while (true) {
            const t = try parseNamedType(parser, tokens, false);
            types.append(t) catch return ParseError.UnexpectedMemoryError;
            const pipeToken = parser.peekNextToken(tokens) orelse break;
            if (pipeToken.tag != Token.Tag.punct_pipe) {
                break;
            }

            _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        }
    }

    return UnionTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .name = unionName,
        .types = types.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
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
    var parser = Parser.init(testing.allocator);
    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    switch (expectedLenOrError) {
        .parseError => |expectedError| {
            const unionTypeDefinition = parseUnionTypeDefinition(&parser, tokens);
            try testing.expectError(expectedError, unionTypeDefinition);
        },
        .len => |length| {
            const unionTypeDefinition = try parseUnionTypeDefinition(&parser, tokens);
            defer unionTypeDefinition.deinit();

            try testing.expectEqual(length, unionTypeDefinition.types.len);
        },
    }
}
