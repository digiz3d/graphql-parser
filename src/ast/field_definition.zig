const std = @import("std");
const Allocator = std.mem.Allocator;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parserImport = @import("../parser.zig");
const Parser = parserImport.Parser;
const ParseError = parserImport.ParseError;
const Token = @import("../tokenizer.zig").Token;
const Argument = @import("argument.zig").Argument;
const parseArguments = @import("argument.zig").parseArguments;
const parseDirectives = @import("directive.zig").parseDirectives;
const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseType = @import("type.zig").parseType;

pub const FieldDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    type: Type,
    // description: ?[]const u8, // TODO: implement description
    arguments: []Argument,
    directives: []Directive,

    pub fn printAST(self: FieldDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FieldDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: FieldDefinition) void {
        self.allocator.free(self.name);
        self.type.deinit();
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseFieldDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) !FieldDefinition {
    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const name = try parser.getTokenValue(nameToken, allocator);
    defer allocator.free(name);

    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const arguments = try parseArguments(parser, tokens, allocator);

    const colonToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (colonToken.tag != Token.Tag.punct_colon) {
        return ParseError.ExpectedColon;
    }

    const namedType = try parseType(parser, tokens, allocator);

    const directives = try parseDirectives(parser, tokens, allocator);

    const fieldDefinition = FieldDefinition{
        .allocator = allocator,
        .name = allocator.dupe(u8, name) catch return ParseError.UnexpectedMemoryError,
        .type = namedType,
        .arguments = arguments,
        .directives = directives,
    };

    return fieldDefinition;
}
