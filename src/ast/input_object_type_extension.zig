const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Directive = @import("directive.zig").Directive;
const InputValueDefinition = @import("input_value_definition.zig").InputValueDefinition;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseInputValueDefinitions = @import("input_value_definition.zig").parseInputValueDefinitions;

pub const InputObjectTypeExtension = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,
    fields: []InputValueDefinition,

    pub fn deinit(self: InputObjectTypeExtension) void {
        self.allocator.free(self.name);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
        for (self.fields) |field| {
            field.deinit();
        }
        self.allocator.free(self.fields);
    }
};

pub fn parseInputObjectTypeExtension(parser: *Parser) ParseError!InputObjectTypeExtension {
    try parser.consumeSpecificIdentifier("extend");
    try parser.consumeSpecificIdentifier("input");

    const nameToken = try parser.consumeToken(Token.Tag.identifier);
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);
    const fields = try parseInputValueDefinitions(parser, true);

    return InputObjectTypeExtension{
        .allocator = parser.allocator,
        .name = name,
        .directives = directives,
        .fields = fields,
    };
}

test "parseInputObjectTypeExtension" {
    try runTest(
        \\extend input SomeInput @lol {
        \\ newField: String
        \\}
    , 1);
}

fn runTest(buffer: [:0]const u8, len: usize) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const inputObjectTypeExtension = try parseInputObjectTypeExtension(&parser);
    defer inputObjectTypeExtension.deinit();

    try testing.expectEqual(len, inputObjectTypeExtension.fields.len);
}
