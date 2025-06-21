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

    pub fn printAST(self: InputObjectTypeExtension, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- InputObjectTypeExtension\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
        std.debug.print("{s}  fields: {d}\n", .{ spaces, self.fields.len });
        for (self.fields) |field| {
            field.printAST(indent + 1);
        }
    }
};

pub fn parseInputObjectTypeExtension(parser: *Parser, tokens: []Token) ParseError!InputObjectTypeExtension {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList; // "extend"
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList; // "input"

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);
    const fields = try parseInputValueDefinitions(parser, tokens, true);

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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const inputObjectTypeExtension = try parseInputObjectTypeExtension(&parser, tokens);
    defer inputObjectTypeExtension.deinit();

    try testing.expectEqual(len, inputObjectTypeExtension.fields.len);
}
