const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;
const parseDirectives = @import("directive.zig").parseDirectives;
const parseSelectionSet = @import("selection_set.zig").parseSelectionSet;
const Type = @import("type.zig").Type;
const parseNamedType = @import("type.zig").parseNamedType;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;
const strEq = @import("../utils/utils.zig").strEq;

pub const FragmentDefinition = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,
    selectionSet: SelectionSet,
    typeCondition: Type,

    pub fn deinit(self: FragmentDefinition) void {
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
        self.typeCondition.deinit();
    }
};

pub fn parseFragmentDefinition(parser: *Parser) ParseError!FragmentDefinition {
    try parser.consumeSpecificIdentifier("fragment");

    const fragmentNameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const fragmentName = try parser.getTokenValue(fragmentNameToken);
    errdefer parser.allocator.free(fragmentName);

    if (strEq(fragmentName, "on")) {
        return ParseError.ExpectedNameNotOn;
    }

    parser.consumeSpecificIdentifier("on") catch return ParseError.ExpectedOn;

    const namedType = try parseNamedType(parser, false);

    const directivesNodes = try parseDirectives(parser);
    const selectionSetNode = try parseSelectionSet(parser);

    return FragmentDefinition{
        .allocator = parser.allocator,
        .name = fragmentName,
        .directives = directivesNodes,
        .selectionSet = selectionSetNode,
        .typeCondition = namedType,
    };
}

test "initialize fragment" {
    const buffer =
        \\fragment Profile on User @SomeDecorator
        \\  @AnotherOne(v: $var, i: 42, f: 0.1234e3 , s: "oui", b: true, n: null e: SOME_ENUM) {
        \\  nickname: username
        \\  avatar {
        \\    thumbnail: picUrl(size: 64)
        \\    fullsize: picUrl
        \\  }
        \\}
    ;

    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();

    const fragmentDefinition = try parseFragmentDefinition(&parser);
    defer fragmentDefinition.deinit();

    try testing.expectEqualStrings(fragmentDefinition.name, "Profile");
}

// error cases
test "initialize invalid fragment no name" {
    const buffer = "fragment { hello }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const rootNode = parser.parse();
    try testing.expectError(ParseError.ExpectedName, rootNode);
}

test "initialize invalid fragment name is on" {
    const buffer = "fragment on on User { hello }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const rootNode = parser.parse();
    try testing.expectError(ParseError.ExpectedNameNotOn, rootNode);
}

test "initialize invalid fragment name after on" {
    const buffer = "fragment X on { hello }";
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const rootNode = parser.parse();
    try testing.expectError(ParseError.ExpectedName, rootNode);
}
