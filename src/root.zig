const std = @import("std");
const Merger = @import("merge.zig").Merger;
const Parser = @import("parser.zig").Parser;

pub const merger = Merger;
pub const parser = Parser;

test {
    std.testing.refAllDecls(@This());
}
