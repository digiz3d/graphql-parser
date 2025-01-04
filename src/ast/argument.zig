const std = @import("std");

const input = @import("../input_value.zig");
const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

pub const Argument = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    value: input.InputValueData,

    pub fn printAST(self: Argument, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- Argument\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        const value = self.value.getPrintableString(self.allocator);
        defer self.allocator.free(value);
        std.debug.print("{s}  value = {s}\n", .{ spaces, value });
    }

    pub fn deinit(self: Argument) void {
        self.allocator.free(self.name);
        self.value.deinit(self.allocator);
    }
};
