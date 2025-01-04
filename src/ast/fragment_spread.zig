const std = @import("std");

const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

const node = @import("./index.zig");

pub const FragmentSpread = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    directives: []node.Directive,

    pub fn printAST(self: FragmentSpread, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- FragmentSpread\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: FragmentSpread) void {
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};
