const std = @import("std");
const node = @import("./index.zig");
const input = @import("../input_value.zig");
const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

const parser = @import("../parser.zig");
const OperationType = parser.OperationType;

pub const VariableDefinition = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    type: []const u8,
    defaultValue: ?input.InputValueData,
    directives: []node.Directive,

    pub fn printAST(self: VariableDefinition, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
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
