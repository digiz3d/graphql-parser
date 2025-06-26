const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const makeIndentation = @import("../utils/utils.zig").makeIndentation;

const ExecutableDefinition = @import("executable_definition.zig").ExecutableDefinition;

pub const Document = struct {
    allocator: Allocator,
    definitions: ArrayList(ExecutableDefinition),

    pub fn deinit(self: Document) void {
        for (self.definitions.items) |item| {
            item.deinit();
        }
        self.definitions.deinit();
    }
};
