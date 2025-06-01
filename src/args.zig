const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = struct {
    file: []const u8 = "graphql.graphql",

    pub fn deinit(self: *Args, allocator: Allocator) void {
        // Only free if it's not the default value
        if (!std.mem.eql(u8, self.file, "graphql.graphql")) {
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
        if (std.mem.eql(u8, arg, "--file") or std.mem.eql(u8, arg, "-f")) {
            if (args.next()) |file_arg| {
                result.file = try allocator.dupe(u8, file_arg);
            }
        }
    }
    return result;
}
