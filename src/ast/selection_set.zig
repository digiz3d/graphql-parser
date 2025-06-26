const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const utils = @import("../utils/utils.zig");
const makeIndentation = utils.makeIndentation;
const strEq = utils.strEq;

const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const Field = @import("field.zig").Field;
const FragmentSpread = @import("fragment_spread.zig").FragmentSpread;
const InlineFragment = @import("inline_fragment.zig").InlineFragment;
const Selection = @import("selection.zig").Selection;

const parseArguments = @import("arguments.zig").parseArguments;
const parseDirectives = @import("directive.zig").parseDirectives;

pub const SelectionSet = struct {
    allocator: Allocator,
    selections: []Selection,

    pub fn deinit(self: SelectionSet) void {
        for (self.selections) |item| {
            item.deinit();
        }
        self.allocator.free(self.selections);
    }
};

pub fn parseSelectionSet(parser: *Parser) ParseError!SelectionSet {
    _ = try parser.consumeToken(Token.Tag.punct_brace_left);
    var currentToken = try parser.consumeToken(Token.Tag.identifier);

    var selections = ArrayList(Selection).init(parser.allocator);

    while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = parser.consumeNextToken() orelse return ParseError.MissingExpectedBrace) {
        if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

        if (currentToken.tag == Token.Tag.punct_spread) {
            const onOrSpreadNameToken = parser.consumeNextToken() orelse return ParseError.UnexpectedMemoryError;
            const onOrSpreadName = onOrSpreadNameToken.getStringValue(parser.allocator) catch "";
            defer parser.allocator.free(onOrSpreadName);

            var selection: Selection = undefined;
            if (strEq(onOrSpreadName, "on")) {
                const typeConditionToken = try parser.consumeToken(Token.Tag.identifier);
                const typeCondition = try parser.getTokenValue(typeConditionToken);
                const directives = try parseDirectives(parser);
                const selectionSet = try parseSelectionSet(parser);
                selection = Selection{
                    .inlineFragment = InlineFragment{
                        .allocator = parser.allocator,
                        .typeCondition = typeCondition,
                        .directives = directives,
                        .selectionSet = selectionSet,
                    },
                };
            } else {
                const directives = try parseDirectives(parser);
                const spreadName = parser.allocator.dupe(u8, onOrSpreadName) catch return ParseError.UnexpectedMemoryError;
                selection = Selection{
                    .fragmentSpread = FragmentSpread{
                        .allocator = parser.allocator,
                        .name = spreadName,
                        .directives = directives,
                    },
                };
            }
            selections.append(selection) catch return ParseError.UnexpectedMemoryError;
            continue;
        }

        const nameOrAlias = try parser.getTokenValue(currentToken);
        const nextToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;
        const name, const alias = if (nextToken.tag == Token.Tag.punct_colon) assign: {
            _ = try parser.consumeToken(Token.Tag.punct_colon);
            const finalNameToken = try parser.consumeToken(Token.Tag.identifier);
            const finalName = try parser.getTokenValue(finalNameToken);
            break :assign .{ finalName, nameOrAlias };
        } else .{ nameOrAlias, null };

        const arguments = try parseArguments(parser);
        const directives = try parseDirectives(parser);

        const potentialNextLeftBrace = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;
        const selectionSet: ?SelectionSet = if (potentialNextLeftBrace.tag == Token.Tag.punct_brace_left) ok: {
            break :ok try parseSelectionSet(parser);
        } else null;

        const fieldNode = Selection{
            .field = Field{
                .allocator = parser.allocator,
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
        .allocator = parser.allocator,
        .selections = selections.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
    };
    return selectionSetNode;
}

test "basic selection set" {
    const buffer = "{ field1 field2(id: 123) @directive }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const selectionSet = try parseSelectionSet(&parser);
    defer selectionSet.deinit();
    try testing.expectEqual(2, selectionSet.selections.len);
}
