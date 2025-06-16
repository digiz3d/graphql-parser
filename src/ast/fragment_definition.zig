const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseSelectionSet = @import("selection_set.zig").parseSelectionSet;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const ParseError = @import("../parser.zig").ParseError;
const strEq = @import("../utils/utils.zig").strEq;

pub const FragmentDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,
    selectionSet: SelectionSet,

    pub fn printAST(self: FragmentDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FragmentDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: FragmentDefinition) void {
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
    }
};

pub fn parseFragmentDefinition(parser: *Parser, tokens: []Token) ParseError!FragmentDefinition {
    _ = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;

    const fragmentNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const fragmentName = try parser.getTokenValue(fragmentNameToken);
    errdefer parser.allocator.free(fragmentName);

    if (fragmentNameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }
    if (strEq(fragmentName, "on")) {
        return ParseError.ExpectedNameNotOn;
    }

    const onToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    const tokenName = try parser.getTokenValue(onToken);
    defer parser.allocator.free(tokenName);

    if (onToken.tag != Token.Tag.identifier or !strEq(tokenName, "on")) {
        return ParseError.ExpectedOn;
    }

    const namedTypeToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (namedTypeToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const directivesNodes = try parseDirectives(parser, tokens);
    const selectionSetNode = try parseSelectionSet(parser, tokens);

    return FragmentDefinition{
        .allocator = parser.allocator,
        .name = fragmentName,
        .directives = directivesNodes,
        .selectionSet = selectionSetNode,
    };
}
