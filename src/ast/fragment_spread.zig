const std = @import("std");
const Allocator = std.mem.Allocator;

const Directive = @import("directive.zig").Directive;

pub const FragmentSpread = struct {
    allocator: Allocator,
    name: []const u8,
    directives: []Directive,

    pub fn deinit(self: FragmentSpread) void {
        self.allocator.free(self.name);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
    }
};
