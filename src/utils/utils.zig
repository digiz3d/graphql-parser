const std = @import("std");

const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

pub fn makeIndentation(indent: usize, allocator: Allocator) []const u8 {
    var spaces = ArrayList(u8).init(allocator);
    const newIndent = indent * 2;
    for (0..newIndent) |_| {
        spaces.append(' ') catch return "";
    }
    return spaces.toOwnedSlice() catch return "";
}

pub inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
