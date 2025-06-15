const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const strEq = @import("../utils/utils.zig").strEq;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const Argument = @import("arguments.zig").InputValueDefinition;
const parseArguments = @import("arguments.zig").parseArguments;

pub const DirectiveDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    arguments: []Argument,
    locations: []const []const u8,
    directives: []Directive,

    pub fn printAST(self: DirectiveDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- DirectiveDefinition\n", .{spaces});
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments:\n", .{spaces});
        for (self.arguments) |arg| {
            arg.printAST(indent + 1);
        }
        std.debug.print("{s}  locations:\n", .{spaces});
        for (self.locations) |location| {
            std.debug.print("{s}    - {s}\n", .{ spaces, location });
        }
        std.debug.print("{s}  directives:\n", .{spaces});
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

    pub fn deinit(self: DirectiveDefinition) void {
        self.allocator.free(self.name);
        for (self.arguments) |arg| {
            arg.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.locations) |location| {
            self.allocator.free(location);
        }
        self.allocator.free(self.locations);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseDirectiveDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!DirectiveDefinition {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const atToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (atToken.tag != Token.Tag.punct_at) {
        return ParseError.ExpectedAt;
    }

    const directiveNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (directiveNameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const directiveName = try parser.getTokenValue(directiveNameToken, allocator);
    defer allocator.free(directiveName);

    const arguments = try parseArguments(parser, tokens, allocator);

    const onToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const onStr = try parser.getTokenValue(onToken, allocator);
    defer allocator.free(onStr);
    if (onToken.tag != Token.Tag.identifier or !strEq(onStr, "on")) {
        return ParseError.ExpectedOn;
    }

    var locations = std.ArrayList([]const u8).init(allocator);
    while (true) {
        const locationToken = parser.consumeNextToken(tokens) orelse break;
        if (locationToken.tag != Token.Tag.identifier) {
            return ParseError.ExpectedName;
        }
        const location = try parser.getTokenValue(locationToken, allocator);
        locations.append(location) catch return ParseError.UnexpectedMemoryError;

        const nextToken = parser.peekNextToken(tokens) orelse break;
        if (nextToken.tag != Token.Tag.punct_pipe) break;
        _ = parser.consumeNextToken(tokens) orelse break;
    }

    const directivesNodes = try parseDirectives(parser, tokens, allocator);

    return DirectiveDefinition{
        .allocator = allocator,
        .name = allocator.dupe(u8, directiveName) catch return ParseError.UnexpectedMemoryError,
        .arguments = arguments,
        .locations = locations.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        .directives = directivesNodes,
    };
}

test "parse directive definition" {
    try runTest(
        "directive @example(arg: String = \"default\") on FIELD | OBJECT",
        .{ .name = "example", .argLen = 1, .onsLen = 2 },
    );
}

// test "parse directive definition with multiple locations" {
//     try runTest(
//         "directive @example on FIELD | OBJECT | INTERFACE",
//         .{ .name = "example", .argLen = 0, .onsLen = 3 },
//     );
// }

fn runTest(buffer: [:0]const u8, expected: struct { name: []const u8, argLen: u8, onsLen: u8 }) !void {
    var parser = Parser.init();

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const directiveDefinition = try parseDirectiveDefinition(&parser, tokens, testing.allocator);
    defer directiveDefinition.deinit();

    try testing.expectEqualStrings(expected.name, directiveDefinition.name);
    try testing.expectEqual(expected.argLen, directiveDefinition.arguments.len);
    try testing.expectEqual(expected.onsLen, directiveDefinition.locations.len);
}
