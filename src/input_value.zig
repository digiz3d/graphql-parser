const std = @import("std");
const allocPrint = std.fmt.allocPrint;
const Allocator = std.mem.Allocator;

pub const InputValueData = union(enum) {
    variable: Variable,
    int_value: IntValue,
    float_value: FloatValue,
    string_value: StringValue,
    boolean_value: BooleanValue,
    null_value: NullValue,
    enum_value: EnumValue,
    list_value: ListValue,

    pub fn getPrintableString(self: InputValueData, allocator: Allocator) []const u8 {
        const typeName = @tagName(self);
        switch (self) {
            InputValueData.variable => {
                const variable = self.variable;
                return allocPrint(allocator, "${s} ({s})", .{ variable.name, typeName }) catch return "";
            },
            InputValueData.int_value => {
                const int_value = self.int_value;
                return allocPrint(allocator, "{d} ({s})", .{ int_value.value, typeName }) catch return "";
            },
            InputValueData.float_value => {
                const float_value = self.float_value;
                return allocPrint(allocator, "{d} ({s})", .{ float_value.value, typeName }) catch return "";
            },
            InputValueData.string_value => {
                const string_value = self.string_value;
                return allocPrint(allocator, "{s} ({s})", .{ string_value.value, typeName }) catch return "";
            },
            InputValueData.boolean_value => {
                const boolean_value = self.boolean_value;
                return allocPrint(allocator, "{s} ({s})", .{ if (boolean_value.value) "true" else "false", typeName }) catch return "";
            },
            InputValueData.null_value => {
                return allocPrint(allocator, "null ({s})", .{typeName}) catch return "";
            },
            InputValueData.enum_value => {
                const enum_value = self.enum_value;
                return allocPrint(allocator, "{s} ({s})", .{ enum_value.name, typeName }) catch return "";
            },
            InputValueData.list_value => {
                // TODO: implement list value printing
                unreachable;
            },
            // TODO: implement object value printing
        }
    }

    pub fn deinit(self: InputValueData, allocator: Allocator) void {
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
    values: []InputValueData,
};

// TODO: implement ObjectValue
// pub const ObjectValue = struct {
// };
