const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const ScalarTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    directives: []Directive,

    pub fn printAST(self: ScalarTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- ScalarTypeDefinition\n", .{spaces});
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives:\n", .{spaces});
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

    pub fn deinit(self: ScalarTypeDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseScalarTypeDefinition(parser: *Parser, tokens: []Token) ParseError!ScalarTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    try parser.consumeSpecificIdentifier(tokens, "scalar");

    const scalarNameToken = try parser.consumeSpecificToken(tokens, Token.Tag.identifier);
    const scalarName = try parser.getTokenValue(scalarNameToken);
    errdefer parser.allocator.free(scalarName);

    const directivesNodes = try parseDirectives(parser, tokens);

    return ScalarTypeDefinition{
        .allocator = parser.allocator,
        .description = description,
        .name = scalarName,
        .directives = directivesNodes,
    };
}

test "parse scalar type definition" {
    try runTest(
        "scalar DateTime @lol",
        .{ .name = "DateTime" },
    );
}

test "parse scalar type definition with directive" {
    try runTest(
        "scalar DateTime @lol",
        .{ .name = "DateTime" },
    );
}

fn runTest(buffer: [:0]const u8, expected: struct { name: []const u8 }) !void {
    var parser = Parser.init(testing.allocator);
    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const scalarTypeDefinition = try parseScalarTypeDefinition(&parser, tokens);
    defer scalarTypeDefinition.deinit();

    try testing.expectEqualStrings(expected.name, scalarTypeDefinition.name);
}
