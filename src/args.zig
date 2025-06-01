const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = struct {
    file: []const u8 = "graphql.graphql",
};

pub fn parseArgs(allocator: Allocator) !Args {
    var args = try std.process.argsWithAllocator(allocator);
    var result = Args{};
    _ = args.next(); // skip program name

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--file") or std.mem.eql(u8, arg, "-f")) {
            if (args.next()) |file_arg| {
                result.file = file_arg;
            }
        }
    }
    return result;
}
