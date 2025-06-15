const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;

pub const ScalarTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,

    pub fn printAST(self: ScalarTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ScalarTypeDefinition\n", .{spaces});
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives:\n", .{spaces});
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

    pub fn deinit(self: ScalarTypeDefinition) void {
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseScalarTypeDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!ScalarTypeDefinition {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const scalarNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (scalarNameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const scalarName = try parser.getTokenValue(scalarNameToken, allocator);
    defer allocator.free(scalarName);

    const directivesNodes = try parseDirectives(parser, tokens, allocator);

    return ScalarTypeDefinition{
        .allocator = allocator,
        .name = allocator.dupe(u8, scalarName) catch return ParseError.UnexpectedMemoryError,
        .directives = directivesNodes,
    };
}

test "parse scalar type definition" {
    try runTest(
        "scalar DateTime @lol",
        .{ .name = "DateTime" },
    );
}

test "parse scalar type definition without directives" {
    try runTest(
        "scalar DateTime",
        .{ .name = "DateTime" },
    );
}

fn runTest(buffer: [:0]const u8, expected: struct { name: []const u8 }) !void {
    var parser = Parser.init();

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const scalarTypeDefinition = try parseScalarTypeDefinition(&parser, tokens, testing.allocator);
    defer scalarTypeDefinition.deinit();

    try testing.expectEqualStrings(expected.name, scalarTypeDefinition.name);
}
