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
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const InputValueDefinition = @import("input_value_definition.zig").InputValueDefinition;
const parseInputValueDefinitions = @import("input_value_definition.zig").parseInputValueDefinitions;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const InputObjectTypeDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,
    fields: []InputValueDefinition,

    pub fn printAST(self: InputObjectTypeDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- InputObjectTypeDefinition\n", .{spaces});
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
        std.debug.print("{s}  fields: {d}\n", .{ spaces, self.fields.len });
        for (self.fields) |field| {
            field.printAST(indent + 1);
        }
    }

    pub fn deinit(self: InputObjectTypeDefinition) void {
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
};

pub fn parseInputObjectTypeDefinition(parser: *Parser, tokens: []Token) ParseError!InputObjectTypeDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList; // input
    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);
    const fields = try parseInputValueDefinitions(parser, tokens, true);

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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const inputObjectTypeDefinition = try parseInputObjectTypeDefinition(&parser, tokens);
    defer inputObjectTypeDefinition.deinit();

    try testing.expectEqualStrings("SomeInput", inputObjectTypeDefinition.name);
    try testing.expectEqualStrings("\"input desc\"", inputObjectTypeDefinition.description.?);
    try testing.expectEqual(1, inputObjectTypeDefinition.directives.len);
    try testing.expectEqualStrings("someDirective", inputObjectTypeDefinition.directives[0].name);
    try testing.expectEqual(1, inputObjectTypeDefinition.fields.len);
    try testing.expectEqualStrings("field", inputObjectTypeDefinition.fields[0].name);
    try testing.expectEqualStrings("String", inputObjectTypeDefinition.fields[0].value.namedType.name);
}
