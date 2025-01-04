const std = @import("std");

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const node = @import("./index.zig");

pub const Directive = struct {
    allocator: std.mem.Allocator,
    arguments: []node.Argument,
    name: []const u8,

    pub fn printAST(self: Directive, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- Directive\n", .{spaces});
        std.debug.print("{s}  name = {s}\n", .{ spaces, self.name });
        std.debug.print("{s}  arguments: {d}\n", .{ spaces, self.arguments.len });
        for (self.arguments) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: Directive) void {
        self.allocator.free(self.name);
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
    }
};
