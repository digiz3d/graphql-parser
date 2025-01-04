const std = @import("std");

const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

const node = @import("./index.zig");

pub const SelectionSet = struct {
    allocator: std.mem.Allocator,
    selections: []node.Selection,

    pub fn printAST(self: SelectionSet, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
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
