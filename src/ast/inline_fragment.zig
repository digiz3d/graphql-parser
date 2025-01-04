const std = @import("std");

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const node = @import("./index.zig");

pub const InlineFragment = struct {
    allocator: std.mem.Allocator,
    typeCondition: []const u8,
    directives: []node.Directive,
    selectionSet: node.SelectionSet,

    pub fn printAST(self: InlineFragment, indent: usize) void {
        const spaces = makeIndentation(indent, self.allocator);
        defer self.allocator.free(spaces);
        std.debug.print("{s}- InlineFragment\n", .{spaces});
        std.debug.print("{s}  typeCondition = {s}\n", .{ spaces, self.typeCondition });
        std.debug.print("{s}  directives: {d}\n", .{ spaces, self.directives.len });
        for (self.directives) |item| {
            item.printAST(indent + 1);
        }
        std.debug.print("{s}  selectionSet: \n", .{spaces});
        self.selectionSet.printAST(indent + 1);
    }

    pub fn deinit(self: InlineFragment) void {
        self.allocator.free(self.typeCondition);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
    }
};
