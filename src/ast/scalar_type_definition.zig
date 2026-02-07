const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parse.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parse.zig").ParseError;

const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const ScalarTypeExtension = @import("scalar_type_extension.zig").ScalarTypeExtension;

pub const ScalarTypeDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    directives: []Directive,

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

    pub fn fromExtension(ext: ScalarTypeExtension) ScalarTypeDefinition {
        return ScalarTypeExtension{
            .allocator = ext.allocator,
            .description = null,
            .name = ext.name,
            .directives = ext.directives,
        };
    }
};

pub fn parseScalarTypeDefinition(parser: *Parser) ParseError!ScalarTypeDefinition {
    const description = try parseOptionalDescription(parser);
    try parser.consumeSpecificIdentifier("scalar");

    const scalarNameToken = try parser.consumeToken(Token.Tag.identifier);
    const scalarName = try parser.getTokenValue(scalarNameToken);
    errdefer parser.allocator.free(scalarName);

    const directivesNodes = try parseDirectives(parser);

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
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const scalarTypeDefinition = try parseScalarTypeDefinition(&parser);
    defer scalarTypeDefinition.deinit();

    try testing.expectEqualStrings(expected.name, scalarTypeDefinition.name);
}
