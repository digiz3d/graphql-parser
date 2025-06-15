const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const arg = @import("argument.zig");
const Argument = arg.Argument;
const parseArguments = arg.parseArguments;

pub const Directive = struct {
    allocator: Allocator,
    arguments: []Argument,
    name: []const u8,

    pub fn printAST(self: Directive, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- Directive\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: Directive) void {
        self.allocator.free(self.name);
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
    }
};

pub fn parseDirectives(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]Directive {
    var directives = ArrayList(Directive).init(allocator);
    var currentToken = parser.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    while (currentToken.tag == Token.Tag.punct_at) : (currentToken = parser.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError) {
        _ = parser.consumeNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        const directiveNameToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

        if (directiveNameToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
        const directiveName = try parser.getTokenValue(directiveNameToken, allocator);
        const arguments = try parseArguments(parser, tokens, allocator);
        const directiveNode = Directive{
            .allocator = allocator,
            .arguments = arguments,
            .name = directiveName,
        };
        directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
    }
    return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing directives" {
    var parser = Parser.init();
    const buffer = "@oneDirective @twoDirective(id: 1, other: $val)";

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const directives = try parseDirectives(&parser, tokens, testing.allocator);
    defer {
        for (directives) |directive| {
            directive.deinit();
        }
        testing.allocator.free(directives);
    }

    try testing.expectEqual(2, directives.len);
}
