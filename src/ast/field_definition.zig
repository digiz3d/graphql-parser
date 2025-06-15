const std = @import("std");
const Allocator = std.mem.Allocator;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const parserImport = @import("../parser.zig");
const Parser = parserImport.Parser;
const ParseError = parserImport.ParseError;
const Token = @import("../tokenizer.zig").Token;
const Argument = @import("arguments.zig").InputValueDefinition;
const parseArguments = @import("arguments.zig").parseArguments;
const parseDirectives = @import("directive.zig").parseDirectives;
const Directive = @import("directive.zig").Directive;
const Type = @import("type.zig").Type;
const parseType = @import("type.zig").parseType;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const FieldDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    type: Type,
    // description: ?[]const u8, // TODO: implement description
    arguments: []Argument,
    directives: []Directive,

    pub fn printAST(self: FieldDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FieldDefinition\n", .{spaces});
        if (self.description != null) {
            std.debug.print("{s}  description: {s}\n", .{ spaces, newLineToBackslashN(self.allocator, self.description.?) });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
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
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
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
    const description = try parseOptionalDescription(parser, tokens, allocator);

    const nameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const name = try parser.getTokenValue(nameToken, allocator);
    defer allocator.free(name);

    if (nameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const arguments = try parseArguments(parser, tokens, allocator, false);

    const colonToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (colonToken.tag != Token.Tag.punct_colon) {
        return ParseError.ExpectedColon;
    }

    const namedType = try parseType(parser, tokens, allocator);

    const directives = try parseDirectives(parser, tokens, allocator);

    const fieldDefinition = FieldDefinition{
        .allocator = allocator,
        .description = description,
        .name = allocator.dupe(u8, name) catch return ParseError.UnexpectedMemoryError,
        .type = namedType,
        .arguments = arguments,
        .directives = directives,
    };

    return fieldDefinition;
}
