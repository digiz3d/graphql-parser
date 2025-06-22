const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;

const parseOptionalDescription = @import("description.zig").parseOptionalDescription;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;

pub const EnumValueDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    description: ?[]const u8,
    directives: []Directive,

    pub fn printAST(self: EnumValueDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- EnumValueDefinition\n", .{spaces});
        if (self.description != null) {
            const str = newLineToBackslashN(self.allocator, self.description.?);
            defer self.allocator.free(str);
            std.debug.print("{s}  description: {s}\n", .{ spaces, str });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

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

pub fn parseEnumValueDefinition(parser: *Parser, tokens: []Token) ParseError!EnumValueDefinition {
    const description = try parseOptionalDescription(parser, tokens);
    const nameToken = parser.consumeSpecificToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(nameToken);
    errdefer parser.allocator.free(name);

    const directives = try parseDirectives(parser, tokens);

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
    var parser = Parser.init(testing.allocator);

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const enumValueDefinition = try parseEnumValueDefinition(&parser, tokens);
    defer enumValueDefinition.deinit();

    try testing.expectEqual(len, enumValueDefinition.directives.len);
}
