const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const InputValueDefinition = @import("input_value_definition.zig").InputValueDefinition;
const parseInputValueDefinitions = @import("input_value_definition.zig").parseInputValueDefinitions;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const InputObjectTypeExtension = @import("input_object_type_extension.zig").InputObjectTypeExtension;

pub const InputObjectTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,
    fields: []InputValueDefinition,

    _is_merge_result: bool = false,

    pub fn deinit(self: InputObjectTypeDefinition) void {
        if (self._is_merge_result) {
            self.allocator.free(self.fields);
            self.allocator.free(self.directives);
            return;
        }
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.fields) |field| {
            field.deinit();
        }
        self.allocator.free(self.fields);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }

    pub fn fromExtension(ext: InputObjectTypeExtension) InputObjectTypeDefinition {
        return InputObjectTypeDefinition{
            .allocator = ext.allocator,
            .name = ext.name,
            .description = null,
            .directives = ext.directives,
            .fields = ext.fields,
        };
    }
};

pub fn parseInputObjectTypeDefinition(parser: *Parser) ParseError!InputObjectTypeDefinition {
    const description = try parseOptionalDescription(parser);
    try parser.consumeSpecificIdentifier("input");
    const nameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser);
    const fields = try parseInputValueDefinitions(parser, true);

    return InputObjectTypeDefinition{
        .allocator = parser.allocator,
        .name = name,
        .description = description,
        .directives = directives,
        .fields = fields,
    };
}

test "parseInputObjectTypeDefinition" {
    try runTest(
        \\"input desc"
        \\input SomeInput @someDirective {
        \\ field: String
        \\}
    );
}

fn runTest(buffer: [:0]const u8) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const inputObjectTypeDefinition = try parseInputObjectTypeDefinition(&parser);
    defer inputObjectTypeDefinition.deinit();

    try testing.expectEqualStrings("SomeInput", inputObjectTypeDefinition.name);
    try testing.expectEqualStrings("\"input desc\"", inputObjectTypeDefinition.description.?);
    try testing.expectEqual(1, inputObjectTypeDefinition.directives.len);
    try testing.expectEqualStrings("someDirective", inputObjectTypeDefinition.directives[0].name);
    try testing.expectEqual(1, inputObjectTypeDefinition.fields.len);
    try testing.expectEqualStrings("field", inputObjectTypeDefinition.fields[0].name);
    try testing.expectEqualStrings("String", inputObjectTypeDefinition.fields[0].value.namedType.name);
}
