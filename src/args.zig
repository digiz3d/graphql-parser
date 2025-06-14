const std = @import("std");
const Allocator = std.mem.Allocator;
const strEq = @import("utils/utils.zig").strEq;

const Args = struct {
    file: []const u8 = "schema.graphql",
    file_owned: bool = false,

    pub fn deinit(self: *Args, allocator: Allocator) void {
        if (self.file_owned) {
            allocator.free(self.file);
        }
    }
};

pub fn parseArgs(allocator: Allocator) !Args {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    var result = Args{};

    _ = args.next(); // skip program name

    while (args.next()) |arg| {
        if (strEq(arg, "--file") or strEq(arg, "-f")) {
            if (args.next()) |file_arg| {
                result.file = try allocator.dupe(u8, file_arg);
                result.file_owned = true;
            }
        }
    }
    return result;
}
