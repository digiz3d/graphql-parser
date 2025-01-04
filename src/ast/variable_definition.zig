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

const d = @import("directive.zig");
const parseDirectives = d.parseDirectives;
const Directive = d.Directive;

const input = @import("input_value.zig");
const InputValue = input.InputValue;
const parseInputValue = input.parseInputValue;

pub const VariableDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    type: []const u8,
    defaultValue: ?InputValue,
    directives: []Directive,

    pub fn printAST(self: VariableDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- VariableDefinition\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  type: {s}\n", .{ spaces, self.type });
        if (self.defaultValue != null) {
            const value = self.defaultValue.?.getPrintableString(self.allocator);
            defer self.allocator.free(value);
            std.debug.print("{s}  defaultValue = {s}\n", .{ spaces, value });
        } else {
            std.debug.print("{s}  defaultValue = null\n", .{spaces});
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: VariableDefinition) void {
        self.allocator.free(self.name);
        self.allocator.free(self.type);
        if (self.defaultValue != null) {
            self.defaultValue.?.deinit(self.allocator);
        }
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseVariableDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError![]VariableDefinition {
    var variableDefinitions = ArrayList(VariableDefinition).init(allocator);

    var currentToken = parser.peekNextToken(tokens) orelse
        return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    if (currentToken.tag != Token.Tag.punct_paren_left) {
        return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
    }

    // consume the left parenthesis
    _ = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

    while (currentToken.tag != Token.Tag.punct_paren_right) : (currentToken = parser.peekNextToken(tokens) orelse
        return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError)
    {
        const variableDollarToken = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (variableDollarToken.tag != Token.Tag.punct_dollar) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedDollar;

        const variableNameToken = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (variableNameToken.tag != Token.Tag.identifier) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedName;
        const variableName = try parser.getTokenValue(variableNameToken, allocator);

        const variableColonToken = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (variableColonToken.tag != Token.Tag.punct_colon) return ParseError.ExpectedColon;

        // TODO: properly parse type (NonNullType, ListType, NamedType)
        const variableTypeToken = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
        if (variableTypeToken.tag != Token.Tag.identifier) return variableDefinitions.toOwnedSlice() catch return ParseError.ExpectedName;
        const variableType = try parser.getTokenValue(variableTypeToken, allocator);

        const nextToken = parser.peekNextToken(tokens) orelse
            return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;

        var defaultValue: ?input.InputValue = null;

        if (nextToken.tag == Token.Tag.punct_equal) {
            _ = parser.consumeNextToken(tokens) orelse return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
            // TODO: don't accept variables values there
            defaultValue = try parseInputValue(parser, tokens, allocator);
        }

        const directives = try parseDirectives(parser, tokens, allocator);

        const variableDefinition = VariableDefinition{
            .allocator = allocator,
            .name = variableName,
            .type = variableType,
            .defaultValue = defaultValue,
            .directives = directives,
        };
        variableDefinitions.append(variableDefinition) catch return ParseError.UnexpectedMemoryError;

        currentToken = parser.peekNextToken(tokens) orelse return ParseError.UnexpectedMemoryError catch return ParseError.UnexpectedMemoryError;
    }

    // consume the right parenthesis
    _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedRightParenthesis catch return ParseError.UnexpectedMemoryError;

    return variableDefinitions.toOwnedSlice() catch return ParseError.UnexpectedMemoryError;
}

test "parsing variables definitions" {
    var parser = Parser.init();
    const buffer = "($name: String, $id: Int)";

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    const variableDefinitions = try parseVariableDefinition(&parser, tokens, testing.allocator);
    defer {
        for (variableDefinitions) |variableDefinition| {
            variableDefinition.deinit();
        }
        testing.allocator.free(variableDefinitions);
    }

    try testing.expectEqual(2, variableDefinitions.len);
}

// TODO: implement parsing NonNull variables definitions
// test "parsing NonNull variables definitions" {
//     var parser = Parser.init();
//     const buffer = "($name: String!, $id: Int!)";

//     var tokenizer = Tokenizer.init(testing.allocator, buffer);
//     defer tokenizer.deinit();

//     const tokens = try tokenizer.getAllTokens();
//     defer testing.allocator.free(tokens);

//     const variableDefinitions = try parseVariableDefinition(&parser, tokens, testing.allocator);
//     defer {
//         for (variableDefinitions) |variableDefinition| {
//             variableDefinition.deinit();
//         }
//         testing.allocator.free(variableDefinitions);
//     }

//     try testing.expectEqual(2, variableDefinitions.len);
// }
