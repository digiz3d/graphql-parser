const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Parser = @import("../parser.zig").Parser;
const Token = @import("../tokenizer.zig").Token;
const Tokenizer = @import("../tokenizer.zig").Tokenizer;
const ParseError = @import("../parser.zig").ParseError;

const strEq = @import("../utils/utils.zig").strEq;
const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const newLineToBackslashN = @import("../utils/utils.zig").newLineToBackslashN;
const Directive = @import("directive.zig").Directive;
const parseDirectives = @import("directive.zig").parseDirectives;
const InputValueDefinition = @import("input_value_definition.zig").InputValueDefinition;
const parseInputValueDefinitions = @import("input_value_definition.zig").parseInputValueDefinitions;
const parseOptionalDescription = @import("description.zig").parseOptionalDescription;

pub const DirectiveDefinition = struct {
    allocator: Allocator,
    description: ?[]const u8,
    name: []const u8,
    arguments: []InputValueDefinition,
    locations: []const []const u8,
    directives: []Directive,

    pub fn printAST(self: DirectiveDefinition, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- DirectiveDefinition\n", .{spaces});
        if (self.description != null) {
            std.debug.print("{s}  description: {s}\n", .{ spaces, newLineToBackslashN(self.allocator, self.description.?) });
        } else {
            std.debug.print("{s}  description: null\n", .{spaces});
        }
        std.debug.print("{s}  name: {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |arg| {
            arg.printAST(indent + 1);
        }
        std.debug.print("{s}  locations: {d}\n", .{ spaces, self.locations.len });
        for (self.locations) |location| {
            std.debug.print("{s}    - {s}\n", .{ spaces, location });
        }
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |directive| {
            directive.printAST(indent + 1);
        }
    }

    pub fn deinit(self: DirectiveDefinition) void {
        if (self.description != null) {
            self.allocator.free(self.description.?);
        }
        self.allocator.free(self.name);
        for (self.arguments) |arg| {
            arg.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.locations) |location| {
            self.allocator.free(location);
        }
        self.allocator.free(self.locations);
        for (self.directives) |directive| {
            directive.deinit();
        }
        self.allocator.free(self.directives);
    }
};

pub fn parseDirectiveDefinition(parser: *Parser, tokens: []Token, allocator: Allocator) ParseError!DirectiveDefinition {
    const description = try parseOptionalDescription(parser, tokens, allocator);

    const directiveToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (directiveToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const atToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (atToken.tag != Token.Tag.punct_at) {
        return ParseError.ExpectedAt;
    }

    const directiveNameToken = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (directiveNameToken.tag != Token.Tag.identifier) {
        return ParseError.ExpectedName;
    }

    const directiveName = try parser.getTokenValue(directiveNameToken, allocator);
    defer allocator.free(directiveName);

    const arguments = try parseInputValueDefinitions(parser, tokens, allocator);

    const onToken = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedOn;
    const onStr = try parser.getTokenValue(onToken, allocator);
    defer allocator.free(onStr);
    if (onToken.tag != Token.Tag.identifier or !strEq(onStr, "on")) {
        return ParseError.ExpectedOn;
    }

    var locations = std.ArrayList([]const u8).init(allocator);
    while (true) {
        const locationToken = parser.consumeNextToken(tokens) orelse break;
        if (locationToken.tag != Token.Tag.identifier) {
            return ParseError.ExpectedName;
        }
        const location = try parser.getTokenValue(locationToken, allocator);
        errdefer allocator.free(location);
        if (!validateLocations(location)) {
            return ParseError.InvalidLocation;
        }
        locations.append(location) catch return ParseError.UnexpectedMemoryError;

        const nextToken = parser.peekNextToken(tokens) orelse break;
        if (nextToken.tag != Token.Tag.punct_pipe) break;
        _ = parser.consumeNextToken(tokens) orelse break;
    }

    if (locations.items.len == 0) {
        return ParseError.ExpectedName;
    }

    const directivesNodes = try parseDirectives(parser, tokens, allocator);

    return DirectiveDefinition{
        .allocator = allocator,
        .description = description,
        .name = allocator.dupe(u8, directiveName) catch return ParseError.UnexpectedMemoryError,
        .arguments = arguments,
        .locations = locations.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        .directives = directivesNodes,
    };
}

const allowedLocations = [_][]const u8{
    // executable directives
    "QUERY",
    "MUTATION",
    "SUBSCRIPTION",
    "FIELD",
    "FRAGMENT_DEFINITION",
    "FRAGMENT_SPREAD",
    "INLINE_FRAGMENT",
    "VARIABLE_DEFINITION",
    // type system directives
    "SCHEMA",
    "SCALAR",
    "OBJECT",
    "FIELD_DEFINITION",
    "ARGUMENT_DEFINITION",
    "INTERFACE",
    "UNION",
    "ENUM",
    "ENUM_VALUE",
    "INPUT_OBJECT",
    "INPUT_FIELD_DEFINITION",
};

fn validateLocations(location: []const u8) bool {
    for (allowedLocations) |allowedLocation| {
        if (strEq(location, allowedLocation)) {
            return true;
        }
    }
    return false;
}

test "missing on" {
    try runTest(
        "directive @example",
        .{ .parseError = ParseError.ExpectedOn },
    );
}

test "missing name" {
    try runTest(
        "directive @example on",
        .{ .parseError = ParseError.ExpectedName },
    );
}

test "valid directive definition" {
    try runTest(
        "directive @example on FIELD",
        .{ .success = .{ .name = "example", .argLen = 0, .onsLen = 1 } },
    );
}

test "invalid variable argument name" {
    try runTest(
        "directive @example($arg: String) on FIELD | OBJECT",
        .{ .parseError = ParseError.ExpectedName },
    );
}

test "invalid variable argument value" {
    try runTest(
        "directive @example(arg: $Nope) on FIELD | OBJECT",
        .{ .parseError = ParseError.ExpectedName },
    );
}

test "with default arg value" {
    try runTest(
        "directive @example(arg: Ok = \"default\") on FIELD | OBJECT",
        .{ .success = .{ .name = "example", .argLen = 1, .onsLen = 2 } },
    );
}

test "invalid direction location" {
    try runTest(
        "directive @example on XXX",
        .{ .parseError = ParseError.InvalidLocation },
    );
}

test "parse directive definition with multiple locations" {
    try runTest(
        "directive @example on FIELD | OBJECT | INTERFACE",
        .{ .success = .{ .name = "example", .argLen = 0, .onsLen = 3 } },
    );
}

fn runTest(buffer: [:0]const u8, expected: union(enum) {
    success: struct {
        name: []const u8,
        argLen: u8,
        onsLen: u8,
    },
    parseError: ParseError,
}) !void {
    var parser = Parser.init();

    var tokenizer = Tokenizer.init(testing.allocator, buffer);
    defer tokenizer.deinit();

    const tokens = try tokenizer.getAllTokens();
    defer testing.allocator.free(tokens);

    switch (expected) {
        .success => |expectedSuccess| {
            const directiveDefinition = try parseDirectiveDefinition(&parser, tokens, testing.allocator);
            defer directiveDefinition.deinit();

            try testing.expectEqualStrings(expectedSuccess.name, directiveDefinition.name);
            try testing.expectEqual(expectedSuccess.argLen, directiveDefinition.arguments.len);
            try testing.expectEqual(expectedSuccess.onsLen, directiveDefinition.locations.len);
        },
        .parseError => |expectedError| {
            const directiveDefinition = parseDirectiveDefinition(&parser, tokens, testing.allocator);
            try testing.expectError(expectedError, directiveDefinition);
        },
    }
}
