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
const Argument = @import("arguments.zig").Argument;
const parseArguments = @import("arguments.zig").parseArguments;

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

pub fn parseDirectives(parser: *Parser, tokens: []Token) ParseError![]Directive {
    var directives = ArrayList(Directive).init(parser.allocator);
    var currentToken = parser.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    while (currentToken.tag == Token.Tag.punct_at) : (currentToken = parser.peekNextToken(tokens) orelse return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError) {
        _ = try parser.consumeSpecificToken(tokens, Token.Tag.punct_at);

        const directiveNameToken = parser.consumeSpecificToken(tokens, Token.Tag.identifier) catch return ParseError.ExpectedName;
        const directiveName = try parser.getTokenValue(directiveNameToken);
        const arguments = try parseArguments(parser, tokens);
        const directiveNode = Directive{
            .allocator = parser.allocator,
            .arguments = arguments,
            .name = directiveName,
        };
        directives.append(directiveNode) catch return ParseError.UnexpectedMemoryError;
    }
    return directives.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing directives" {
    var parser = Parser.init(testing.allocator);
    const buffer = "@oneDirective @twoDirective(id: 1, other: $val)";

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const directives = try parseDirectives(&parser, tokens);
    defer {
        for (directives) |directive| {
            directive.deinit();
        }
        testing.allocator.free(directives);
    }

    try testing.expectEqual(2, directives.len);
}
