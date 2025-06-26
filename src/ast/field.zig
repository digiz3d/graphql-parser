const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Argument = @import("arguments.zig").Argument;
const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;

pub const Field = struct {
    allocator: Allocator,
    name: []const u8,
    alias: ?[]const u8,
    arguments: []Argument,
    directives: []Directive,
    selectionSet: ?SelectionSet,

    pub fn deinit(self: Field) void {
        self.allocator.free(self.name);
        if (self.alias != null) {
            self.allocator.free(self.alias.?);
        }
        for (self.arguments) |item| {
            item.deinit();
        }
        self.allocator.free(self.arguments);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        if (self.selectionSet != null) {
            self.selectionSet.?.deinit();
        }
    }
};
