const std = @import("std");

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const node = @import("./index.zig");

pub const Document = struct {
    allocator: std.mem.Allocator,
    definitions: std.ArrayList(node.ExecutableDefinition),

    pub fn printAST(self: Document, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- Document\n", .{spaces});
        std.debug.print("{s}  definitions: {d}\n", .{ spaces, self.definitions.items.len });
        for (self.definitions.items) |item| {
            item.printAST(indent + 1);
        }
    }

    pub fn deinit(self: Document) void {
        for (self.definitions.items) |item| {
            item.deinit();
        }
        self.definitions.deinit();
    }
};
