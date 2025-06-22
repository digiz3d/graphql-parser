const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;
const t = @import("../tokenizer.zig");
const Token = t.Token;
const Tokenizer = t.Tokenizer;
const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;

const Field = @import("field.zig").Field;

const NamedType = struct {
    allocator: Allocator,
    name: []const u8,

    pub fn printAST(self: NamedType, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        std.debug.print("{s}- NamedType\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
    }

    pub fn deinit(self: NamedType) void {
        self.allocator.free(self.name);
    }

    pub fn getPrintableString(self: NamedType, allocator: Allocator) []const u8 {
        return std.fmt.allocPrint(allocator, "{s}", .{self.name}) catch return "";
    }
};

const ListType = struct {
    allocator: Allocator,
    elementType: *Type,

    pub fn printAST(self: ListType, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);

        std.debug.print("{s}- ListType\n", .{spaces});
        std.debug.print("{s}  type\n", .{spaces});
        self.elementType.*.printAST(indent + 1, self.allocator);
    }

    pub fn deinit(self: ListType) void {
        self.elementType.*.deinit();
        self.allocator.destroy(self.elementType);
    }

    pub fn getPrintableString(self: ListType, allocator: Allocator) []const u8 {
        const elementType = self.elementType.*.getPrintableString(allocator);
        defer allocator.free(elementType);
        return std.fmt.allocPrint(allocator, "[{s}]", .{elementType}) catch return "";
    }
};

const NonNullType = union(enum) {
    namedType: NamedType,
    listType: ListType,

    pub fn printAST(self: NonNullType, indent: usize, allocator: Allocator) void {
        const spaces = makeIndentation(indent, allocator);
        defer allocator.free(spaces);

        std.debug.print("{s}- NonNullType\n", .{spaces});
        std.debug.print("{s}  type\n", .{spaces});
        switch (self) {
            .namedType => |n| n.printAST(indent + 1),
            .listType => |n| n.printAST(indent + 1),
        }
    }

    pub fn deinit(self: NonNullType) void {
        switch (self) {
            .namedType => |n| n.deinit(),
            .listType => |n| n.deinit(),
        }
    }

    pub fn getPrintableString(self: NonNullType, allocator: Allocator) []const u8 {
        const baseType = switch (self) {
            .namedType => |n| n.getPrintableString(allocator),
            .listType => |n| n.getPrintableString(allocator),
        };
        defer allocator.free(baseType);
        return std.fmt.allocPrint(allocator, "{s}!", .{baseType}) catch return "";
    }
};

pub const Type = union(enum) {
    namedType: NamedType,
    listType: ListType,
    nonNullType: NonNullType,

    pub fn printAST(self: Type, indent: usize, allocator: Allocator) void {
        switch (self) {
            .namedType => |n| n.printAST(indent),
            .listType => |n| n.printAST(indent),
            .nonNullType => |n| n.printAST(indent, allocator),
        }
    }

    pub fn deinit(self: Type) void {
        switch (self) {
            .namedType => |n| n.deinit(),
            .listType => |n| n.deinit(),
            .nonNullType => |n| n.deinit(),
        }
    }

    pub fn getPrintableString(self: Type, allocator: Allocator) []const u8 {
        return switch (self) {
            .namedType => |n| n.getPrintableString(allocator),
            .listType => |n| n.getPrintableString(allocator),
            .nonNullType => |n| n.getPrintableString(allocator),
        };
    }
};

pub fn parseNamedType(parser: *Parser, allowNonNull: bool) ParseError!Type {
    const typeNameToken = parser.consumeToken(Token.Tag.identifier) catch return ParseError.ExpectedName;
    const name = try parser.getTokenValue(typeNameToken);
    errdefer parser.allocator.free(name);

    var temporaryType = Type{
        .namedType = NamedType{
            .allocator = parser.allocator,
            .name = name,
        },
    };

    const nextToken = parser.peekNextToken() orelse return temporaryType;
    if (nextToken.tag == Token.Tag.punct_excl) {
        if (!allowNonNull) {
            return ParseError.UnexpectedExclamationMark;
        }

        _ = try parser.consumeToken(Token.Tag.punct_excl);
        temporaryType = wrapNonNullType(temporaryType);
    }

    return temporaryType;
}

fn parseListType(parser: *Parser) ParseError!Type {
    _ = try parser.consumeToken(Token.Tag.punct_bracket_left);

    const elementType: *Type = parser.allocator.create(Type) catch return ParseError.UnexpectedMemoryError;
    elementType.* = try parseType(parser);

    _ = try parser.consumeToken(Token.Tag.punct_bracket_right);

    var temporaryType = Type{
        .listType = ListType{
            .allocator = parser.allocator,
            .elementType = elementType,
        },
    };

    const nextToken = parser.peekNextToken() orelse return temporaryType;
    if (nextToken.tag == Token.Tag.punct_excl) {
        _ = try parser.consumeToken(Token.Tag.punct_excl);
        temporaryType = wrapNonNullType(temporaryType);
    }

    return temporaryType;
}

fn wrapNonNullType(tempType: Type) Type {
    switch (tempType) {
        .namedType => |n| {
            return Type{ .nonNullType = NonNullType{
                .namedType = n,
            } };
        },
        .listType => |n| {
            return Type{ .nonNullType = NonNullType{
                .listType = n,
            } };
        },
        else => unreachable,
    }
}

pub fn parseType(parser: *Parser) ParseError!Type {
    const typeNameOrListToken = parser.peekNextToken() orelse return ParseError.UnexpectedMemoryError;

    if (typeNameOrListToken.tag == Token.Tag.identifier) {
        return parseNamedType(parser, true);
    } else if (typeNameOrListToken.tag == Token.Tag.punct_bracket_left) {
        return parseListType(parser);
    }

    return ParseError.ExpectedName;
}

test "parsing simple type" {
    try runTest(
        "String",
        Type{
            .namedType = NamedType{
                .allocator = testing.allocator,
                .name = "String",
            },
        },
    );
}

test "parsing mandatory simple type" {
    try runTest("String!", Type{
        .nonNullType = NonNullType{
            .namedType = NamedType{
                .allocator = testing.allocator,
                .name = "String",
            },
        },
    });
}

test "parsing array type" {
    var elementType = Type{
        .namedType = NamedType{
            .allocator = testing.allocator,
            .name = "String",
        },
    };
    const listType = Type{
        .listType = ListType{
            .allocator = testing.allocator,
            .elementType = &elementType,
        },
    };
    try runTest("[String]", listType);
}

test "parsing mandatory array of simple type" {
    var elementType = Type{
        .namedType = NamedType{
            .allocator = testing.allocator,
            .name = "String",
        },
    };

    const nonNullType = Type{
        .nonNullType = NonNullType{
            .listType = ListType{
                .allocator = testing.allocator,
                .elementType = &elementType,
            },
        },
    };
    try runTest("[String]!", nonNullType);
}

test "parsing mandatory array of mandatory simple type" {
    var elementType = Type{
        .nonNullType = NonNullType{
            .namedType = NamedType{
                .allocator = testing.allocator,
                .name = "String",
            },
        },
    };

    const nonNullType = Type{
        .nonNullType = NonNullType{
            .listType = ListType{
                .allocator = testing.allocator,
                .elementType = &elementType,
            },
        },
    };
    try runTest("[String!]!", nonNullType);
}

test "parsing mandatory array of array of mandatory simple type" {
    var subElementType = Type{
        .nonNullType = NonNullType{
            .namedType = NamedType{
                .allocator = testing.allocator,
                .name = "String",
            },
        },
    };
    var elementType = Type{
        .listType = ListType{
            .allocator = testing.allocator,
            .elementType = &subElementType,
        },
    };
    const nonNullType = Type{
        .nonNullType = NonNullType{
            .listType = ListType{
                .allocator = testing.allocator,
                .elementType = &elementType,
            },
        },
    };
    try runTest("[[String!]]!", nonNullType);
}

fn runTest(buffer: [:0]const u8, comparison: Type) !void {
    var parser = try Parser.initFromBuffer(testing.allocator, buffer);
    defer parser.deinit();
    const ok = try parseType(&parser);
    defer ok.deinit();
    try expectDeepEqual(ok, comparison);
}

fn expectDeepEqual(val1: Type, val2: Type) !void {
    switch (val1) {
        .namedType => |a| {
            switch (val2) {
                .namedType => |b| {
                    return testing.expectEqualStrings(a.name, b.name);
                },
                else => return testing.expect(false),
            }
        },
        .listType => |a| {
            switch (val2) {
                .listType => |b| {
                    return expectDeepEqual(a.elementType.*, b.elementType.*);
                },
                else => return testing.expect(false),
            }
        },
        .nonNullType => |a| {
            switch (val2) {
                .nonNullType => |b| {
                    switch (a) {
                        .namedType => |aa| {
                            switch (b) {
                                .namedType => |bb| return testing.expectEqualStrings(aa.name, bb.name),
                                else => return testing.expect(false),
                            }
                        },
                        .listType => |aa| {
                            switch (b) {
                                .listType => |bb| return expectDeepEqual(aa.elementType.*, bb.elementType.*),
                                else => return testing.expect(false),
                            }
                        },
                    }
                },
                else => return testing.expect(false),
            }
        },
    }
}
