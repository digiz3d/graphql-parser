const std = @import("std");

const DefinitionData = @import("../parser.zig").DefinitionData;
const makeSpaceFromNumber = @import("../utils/utils.zig").makeSpaceFromNumber;

const node = @import("./index.zig");

pub const Document = struct {
    allocator: std.mem.Allocator,
    definitions: std.ArrayList(DefinitionData),

    pub fn printAST(self: Document, indent: usize) void {
        const spaces = makeSpaceFromNumber(indent, self.allocator);
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
