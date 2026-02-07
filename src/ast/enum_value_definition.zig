const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parse.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parse.zig").ParseError;

const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;

const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub const EnumValueDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,

    pub fn deinit(self: EnumValueDefinition) void {
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

pub fn parseEnumValueDefinition(parser: *Parser) ParseError!EnumValueDefinition {
    const description = try parseOptionalDescription(parser);
    const nameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);

    return EnumValueDefinition{
        .allocator = parser.allocator,
        .name = name,
        .description = description,
        .directives = directives,
    };
}

test "parseEnumValueDefinition" {
    try runTest("oui", 0);
}
test "parseEnumValueDefinition with directives" {
    try runTest("oui @ok @check", 2);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const enumValueDefinition = try parseEnumValueDefinition(&parser);
    defer enumValueDefinition.deinit();

    try testing.expectEqual(len, enumValueDefinition.directives.len);
}
