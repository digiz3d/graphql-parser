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

pub fn parseSelectionSet(parser: *Parser, tokens: []Token) ParseError!SelectionSet {
    _ = try parser.consumeToken(tokens, Token.Tag.punct_brace_left);
    var currentToken = try parser.consumeToken(tokens, Token.Tag.identifier);

    var selections = ArrayList(Selection).init(parser.allocator);

    while (currentToken.tag != Token.Tag.punct_brace_right) : (currentToken = parser.consumeNextToken(tokens) orelse return ParseError.MissingExpectedBrace) {
        if (currentToken.tag == Token.Tag.eof) return ParseError.MissingExpectedBrace;

        if (currentToken.tag == Token.Tag.punct_spread) {
            const onOrSpreadNameToken = parser.consumeNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
            const onOrSpreadName = onOrSpreadNameToken.getStringValue(parser.allocator) catch "";
            defer parser.allocator.free(onOrSpreadName);

            var selection: Selection = undefined;
            if (strEq(onOrSpreadName, "on")) {
                const typeConditionToken = try parser.consumeToken(tokens, Token.Tag.identifier);
                const typeCondition = try parser.getTokenValue(typeConditionToken);
                const directives = try parseDirectives(parser, tokens);
                const selectionSet = try parseSelectionSet(parser, tokens);
                selection = Selection{
                    .inlineFragment = InlineFragment{
                        .allocator = parser.allocator,
                        .typeCondition = typeCondition,
                        .directives = directives,
                        .selectionSet = selectionSet,
                    },
                };
            } else {
                const directives = try parseDirectives(parser, tokens);
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
        const nextToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        const name, const alias = if (nextToken.tag == Token.Tag.punct_colon) assign: {
            _ = try parser.consumeToken(tokens, Token.Tag.punct_colon);
            const finalNameToken = try parser.consumeToken(tokens, Token.Tag.identifier);
            const finalName = try parser.getTokenValue(finalNameToken);
            break :assign .{ finalName, nameOrAlias };
        } else .{ nameOrAlias, null };

        const arguments = try parseArguments(parser, tokens);
        const directives = try parseDirectives(parser, tokens);

        const potentialNextLeftBrace = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError;
        const selectionSet: ?SelectionSet = if (potentialNextLeftBrace.tag == Token.Tag.punct_brace_left) ok: {
            break :ok try parseSelectionSet(parser, tokens);
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
    const selectionSet = try runTest(buffer);
    defer selectionSet.deinit();
    try testing.expectEqual(2, selectionSet.selections.len);
}

fn runTest(buffer: [:0]const u8) !SelectionSet {
    var parser = Parser.init(testing.allocator);
    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    return parseSelectionSet(&parser, tokens);
}
