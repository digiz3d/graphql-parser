const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Directive = @import("directive.zig").Directive;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parseDirectives = @import("directive.zig").parseDirectives;

pub const ScalarTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,

    pub fn deinit(self: ScalarTypeExtension) void {
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseScalarTypeExtension(parser: *Parser) ParseError!ScalarTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("scalar");

    const nameToken = try parser.consumeToken(Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);

    if (directives.len == 0) {
        return ParseError.ExpectedAt;
    }

    return ScalarTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .directives = directives,
    };
}

test "parseScalarTypeExtension" {
    try runTest(
        \\extend scalar DateTime @someDirective
    );
}

test "parseScalarTypeExtension with multiple directives" {
    try runTest(
        \\extend scalar DateTime @directive1 @directive2
    );
}

test "parseScalarTypeExtension without directives" {
    try runTestWithoutDirectives(
        \\extend scalar DateTime
    );
}

fn runTest(buffer: [:0]const u8) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const scalarTypeExtension = try parseScalarTypeExtension(&parser);
    defer scalarTypeExtension.deinit();

    try testing.expectEqualStrings("DateTime", scalarTypeExtension.name);
}

fn runTestWithoutDirectives(buffer: [:0]const u8) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const scalarTypeExtension = parseScalarTypeExtension(&parser);
    try testing.expectError(ParseError.ExpectedAt, scalarTypeExtension);
}
