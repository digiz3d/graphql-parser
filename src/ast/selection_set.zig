const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const Token = @import("../tokenizer.zig").Token;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;
const strEq = @import("../utils/utils.zig").strEq;

const Field = @import("field.zig").Field;
const FragmentSpread = @import("fragment_spread.zig").FragmentSpread;
const InlineFragment = @import("inline_fragment.zig").InlineFragment;
const Selection = @import("selection.zig").Selection;

const parseArguments = @import("argument.zig").parseArguments;
const parseDirectives = @import("directive.zig").parseDirectives;

pub const SelectionSet = struct {
    allocator: Allocator,
    selections: []Selection,

    pub fn printAST(self: SelectionSet, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- SelectionSet\n", .{spaces});
        std.debug.print("{s}  selections:\n", .{spaces});
        for (self.selections) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: SelectionSet) void {
        for (self.selections) |item| {
            item.deinit();
        }
        self.allocator.free(self.selections);
    }
};

pub fn parseSelectionSet(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!SelectionSet {
    const openBraceToken = parser.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace;
    if (openBraceToken.tag != Token.Tag.punct_brace_left) {
        return ParseError.MissingExpectedBrace;
    }
    var currentToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;

    var selections = ArrayList(Selection).init(allocator);

    while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = parser.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
        if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

        if (currentToken.tag == Token.Tag.punct_spread) {
            const onOrSpreadNameToken = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            const onOrSpreadName = onOrSpreadNameToken.getStringValue(allocator) catch "";
            defer allocator.free(onOrSpreadName);

            var selection: Selection = undefined;
            if (strEq(onOrSpreadName, "on")) {
                const typeConditionToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
                if (typeConditionToken.tag != Token.Tag.identifier) return ParseError.ExpectedName;
                const typeCondition = try parser.getTokenValue(typeConditionToken, allocator);
                const directives = try parseDirectives(parser, tokens, allocator);
                const selectionSet = try parseSelectionSet(parser, tokens, allocator);
                selection = Selection{
                    .inlineFragment = InlineFragment{
                        .allocator = allocator,
                        .typeCondition = typeCondition,
                        .directives = directives,
                        .selectionSet = selectionSet,
                    },
                };
            } else {
                const directives = try parseDirectives(parser, tokens, allocator);
                const spreadName = allocator.dupe(u8, onOrSpreadName) catch return ParseError.UnexpectedMemoryError;
                selection = Selection{
                    .fragmentSpread = FragmentSpread{
                        .allocator = allocator,
                        .name = spreadName,
                        .directives = directives,
                    },
                };
            }
            selections.append(selection) catch return ParseError.UnexpectedMemoryError;
            continue;
        }

        const nameOrAlias = try parser.getTokenValue(currentToken, allocator);
        const nextToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        const name, const alias = if (nextToken.tag == Token.Tag.punct_colon) assign: {
            // consume colon
            _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
            const finalNameToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedName;
            const finalName = try parser.getTokenValue(finalNameToken, allocator);
            break :assign .{ finalName, nameOrAlias };
        } else .{ nameOrAlias, null };

        const arguments = try parseArguments(parser, tokens, allocator);
        const directives = try parseDirectives(parser, tokens, allocator);

        const potentialNextLeftBrace = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        const selectionSet: ?SelectionSet = if (potentialNextLeftBrace.tag == Token.Tag.punct_brace_left) ok: {
            break :ok try parseSelectionSet(parser, tokens, allocator);
        } else null;

        const fieldNode = Selection{
            .field = Field{
                .allocator = allocator,
                .name = name,
                .alias = alias,
                .arguments = arguments,
                .directives = directives,
                .selectionSet = selectionSet,
            },
        };
        selections.append(fieldNode) catch return ParseError.UnexpectedMemoryError;
    }

    const selectionSetNode = SelectionSet{
        .allocator = allocator,
        .selections = selections.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
    return selectionSetNode;
}
