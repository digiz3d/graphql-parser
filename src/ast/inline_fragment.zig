const std = @import("std");
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const Directive = @import("directive.zig").Directive;
const SelectionSet = @import("selection_set.zig").SelectionSet;

pub const InlineFragment = struct {
    allocator: Allocator,
    typeCondition: []const u8,
    directives: []Directive,
    selectionSet: SelectionSet,

    pub fn deinit(self: InlineFragment) void {
        self.allocator.free(self.typeCondition);
        for (self.directives) |item| {
            item.deinit();
        }
        self.allocator.free(self.directives);
        self.selectionSet.deinit();
    }
};
