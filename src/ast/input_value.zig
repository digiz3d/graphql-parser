const std = @import("std");
const allocPrint = std.fmt.allocPrint;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const p = @import("../parser.zig");
const Parser = p.Parser;
const ParseError = p.ParseError;
const strEq = @import("../utils/utils.zig").strEq;
const Token = @import("../tokenizer.zig").Token;

pub const InputValue = union(enum) {
    variable: Variable,
    int_value: IntValue,
    float_value: FloatValue,
    string_value: StringValue,
    boolean_value: BooleanValue,
    null_value: NullValue,
    enum_value: EnumValue,
    list_value: ListValue,
    object_value: ObjectValue,

    pub fn getPrintableString(self: InputValue, allocator: Allocator) []const u8 {
        const typeName = @tagName(self);
        switch (self) {
            InputValue.variable => {
                const variable = self.variable;
                return allocPrint(allocator, "${s} ({s})", .{ variable.name, typeName }) catch return "";
            },
            InputValue.int_value => {
                const int_value = self.int_value;
                return allocPrint(allocator, "{d} ({s})", .{ int_value.value, typeName }) catch return "";
            },
            InputValue.float_value => {
                const float_value = self.float_value;
                return allocPrint(allocator, "{d} ({s})", .{ float_value.value, typeName }) catch return "";
            },
            InputValue.string_value => {
                const string_value = self.string_value;
                return allocPrint(allocator, "{s} ({s})", .{ string_value.value, typeName }) catch return "";
            },
            InputValue.boolean_value => {
                const boolean_value = self.boolean_value;
                return allocPrint(allocator, "{} ({s})", .{ boolean_value.value, typeName }) catch return "";
            },
            InputValue.null_value => {
                return allocPrint(allocator, "null ({s})", .{typeName}) catch return "";
            },
            InputValue.enum_value => {
                const enum_value = self.enum_value;
                return allocPrint(allocator, "{s} ({s})", .{ enum_value.name, typeName }) catch return "";
            },
            InputValue.list_value => {
                const list_value = self.list_value;
                var result = ArrayList(u8).init(allocator);
                defer result.deinit();

                result.appendSlice("[") catch return "";
                for (list_value.values, 0..) |value, i| {
                    if (i > 0) result.appendSlice(", ") catch return "";
                    result.appendSlice(value.getPrintableString(allocator)) catch return "";
                }
                result.appendSlice("]") catch return "";

                return result.toOwnedSlice() catch return "";
            },
            InputValue.object_value => {
                const object_value = self.object_value;
                var result = ArrayList(u8).init(allocator);
                defer result.deinit();

                result.appendSlice("{") catch return "";
                for (object_value.fields, 0..) |field, i| {
                    if (i > 0) result.appendSlice(", ") catch return "";
                    result.appendSlice(field.name) catch return "";
                    result.appendSlice(": ") catch return "";
                    result.appendSlice(field.value.getPrintableString(allocator)) catch return "";
                }
                result.appendSlice("}") catch return "";

                return result.toOwnedSlice() catch return "";
            },
        }
    }

    pub fn deinit(self: InputValue, allocator: Allocator) void {
        switch (self) {
            .variable => |*x| {
                allocator.free(x.name);
            },
            .int_value => {},
            .float_value => {},
            .string_value => |*x| {
                allocator.free(x.value);
            },
            .boolean_value => {},
            .null_value => {},
            .enum_value => |*x| {
                allocator.free(x.name);
            },
            .list_value => |*x| {
                for (x.values) |value| {
                    value.deinit(allocator);
                }
                allocator.free(x.values);
            },
            .object_value => |*x| {
                for (x.fields) |field| {
                    field.value.deinit(allocator);
                    allocator.free(field.name);
                }
                allocator.free(x.fields);
            },
        }
    }
};

pub const Variable = struct {
    name: []const u8,
};

pub const IntValue = struct {
    value: i32,
};

pub const FloatValue = struct {
    value: f64,
};

pub const StringValue = struct {
    value: []const u8,
    block: bool,
};

pub const BooleanValue = struct {
    value: bool,
};

pub const NullValue = struct {};

pub const EnumValue = struct {
    name: []const u8,
};

pub const ListValue = struct {
    values: []InputValue,
};

pub const ObjectValue = struct {
    fields: []ObjectField,
};

pub const ObjectField = struct {
    name: []const u8,
    value: InputValue,
};

pub fn parseInputValue(parser: *Parser, tokens: []Token, acceptVariables: bool) ParseError!InputValue {
    var token = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag == Token.Tag.punct_dollar and !acceptVariables) {
        return ParseError.ExpectedName;
    }

    var str = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;
    defer parser.allocator.free(str);

    switch (token.tag) {
        Token.Tag.punct_brace_left,
        Token.Tag.punct_bracket_left,
        => {},
        else => {
            token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
        },
    }

    switch (token.tag) {
        Token.Tag.integer_literal => return InputValue{
            .int_value = IntValue{
                .value = std.fmt.parseInt(i32, str, 10) catch return ParseError.UnexpectedMemoryError,
            },
        },
        Token.Tag.float_literal => return InputValue{
            .float_value = FloatValue{
                .value = std.fmt.parseFloat(f64, str) catch return ParseError.UnexpectedMemoryError,
            },
        },
        Token.Tag.string_literal, Token.Tag.string_literal_block => {
            const strCopy = parser.allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .string_value = StringValue{
                    .value = strCopy,
                    .block = token.tag == Token.Tag.string_literal_block,
                },
            };
        },
        Token.Tag.identifier => {
            if (strEq(str, "true")) {
                return InputValue{
                    .boolean_value = BooleanValue{
                        .value = true,
                    },
                };
            } else if (strEq(str, "false")) {
                return InputValue{
                    .boolean_value = BooleanValue{
                        .value = false,
                    },
                };
            } else if (strEq(str, "null")) {
                return InputValue{
                    .null_value = NullValue{},
                };
            } else {
                return InputValue{
                    .enum_value = EnumValue{
                        .name = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError,
                    },
                };
            }
        },
        Token.Tag.punct_dollar => {
            token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
            parser.allocator.free(str);
            str = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;

            const strCopy = parser.allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .variable = Variable{
                    .name = strCopy,
                },
            };
        },
        Token.Tag.punct_brace_left => {
            return parseObjectValue(parser, tokens);
        },
        Token.Tag.punct_bracket_left => {
            return parseListValue(parser, tokens);
        },
        else => return ParseError.NotImplemented,
    }
    return ParseError.NotImplemented;
}

fn parseListValue(parser: *Parser, tokens: []Token) ParseError!InputValue {
    var token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag != Token.Tag.punct_bracket_left) {
        return ParseError.UnexpectedToken;
    }

    var values = ArrayList(InputValue).init(parser.allocator);

    while (true) {
        token = parser.peekNextToken(tokens) orelse return ParseError.EmptyTokenList;
        if (token.tag == Token.Tag.punct_bracket_right) {
            _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedBracketRight;
            break;
        }
        const value = try parseInputValue(parser, tokens, false);
        values.append(value) catch return ParseError.UnexpectedMemoryError;
    }

    return InputValue{
        .list_value = ListValue{
            .values = values.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        },
    };
}

fn parseObjectValue(parser: *Parser, tokens: []Token) ParseError!InputValue {
    var token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag != Token.Tag.punct_brace_left) {
        std.debug.print("token 1: {}\n", .{token.tag});
        return ParseError.UnexpectedToken;
    }

    var fields = ArrayList(ObjectField).init(parser.allocator);

    while (true) {
        token = parser.peekNextToken(tokens) orelse return ParseError.ExpectedBraceRight;
        if (token.tag == Token.Tag.punct_brace_right) {
            _ = parser.consumeNextToken(tokens) orelse return ParseError.ExpectedBraceRight;
            break;
        }
        const field = try parseObjectField(parser, tokens);
        fields.append(field) catch return ParseError.UnexpectedMemoryError;
    }

    return InputValue{
        .object_value = ObjectValue{
            .fields = fields.toOwnedSlice() catch return ParseError.UnexpectedMemoryError,
        },
    };
}

fn parseObjectField(parser: *Parser, tokens: []Token) ParseError!ObjectField {
    var token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag != Token.Tag.identifier) {
        std.debug.print("token 2: {}\n", .{token.tag});
        return ParseError.UnexpectedToken;
    }
    const name = token.getStringValue(parser.allocator) catch return ParseError.UnexpectedMemoryError;
    token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag != Token.Tag.punct_colon) {
        std.debug.print("token 3: {}\n", .{token});
        return ParseError.UnexpectedToken;
    }
    const value = try parseInputValue(parser, tokens, false);
    return ObjectField{
        .name = name,
        .value = value,
    };
}
