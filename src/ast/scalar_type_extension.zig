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

    pub fn printAST(self: ScalarTypeExtension, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ScalarTypeExtension\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }
};

pub fn parseScalarTypeExtension(parser: *Parser, tokens: []Token) ParseError!ScalarTypeExtension {
    try parser.consumeSpecificIdentifier(tokens, "extend");
    try parser.consumeSpecificIdentifier(tokens, "scalar");

    const nameToken = try parser.consumeSpecificToken(tokens, Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);

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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const scalarTypeExtension = try parseScalarTypeExtension(&parser, tokens);
    defer scalarTypeExtension.deinit();

    try testing.expectEqualStrings("DateTime", scalarTypeExtension.name);
}

fn runTestWithoutDirectives(buffer: [:0]const u8) !void {
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const scalarTypeExtension = parseScalarTypeExtension(&parser, tokens);
    try testing.expectError(ParseError.ExpectedAt, scalarTypeExtension);
}
