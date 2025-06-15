const std = @import("std");
const allocPrint = std.fmt.allocPrint;
const Allocator = std.mem.Allocator;

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
                // TODO: implement list value printing
                unreachable;
            },
            // TODO: implement object value printing
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
            .list_value => {
                // TODO: implement list value deinit
                unreachable;
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

// TODO: implement ObjectValue
// pub const ObjectValue = struct {
// };

pub fn parseInputValue(parser: *Parser, tokens: []Token, allocator: Allocator, acceptVariables: bool) ParseError!InputValue {
    var token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
    if (token.tag == Token.Tag.punct_dollar and !acceptVariables) {
        return ParseError.ExpectedName;
    }

    var str = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError;
    defer allocator.free(str);

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
        Token.Tag.string_literal => {
            const strCopy = allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .string_value = StringValue{
                    .value = strCopy,
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
                        .name = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError,
                    },
                };
            }
        },
        Token.Tag.punct_dollar => {
            token = parser.consumeNextToken(tokens) orelse return ParseError.EmptyTokenList;
            allocator.free(str);
            str = token.getStringValue(allocator) catch return ParseError.UnexpectedMemoryError;

            const strCopy = allocator.dupe(u8, str) catch return ParseError.UnexpectedMemoryError;
            return InputValue{
                .variable = Variable{
                    .name = strCopy,
                },
            };
        },
        else => return ParseError.NotImplemented,
    }
    return ParseError.NotImplemented;
}
