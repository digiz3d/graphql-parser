const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Allocator = std.mem.Allocator;
const parseArgs = @import("args.zig").parseArgs;
const getFileContent = @import("utils/utils.zig").getFileContent;
const Printer = @import("printer.zig").Printer;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try parseArgs(allocator);
    defer args.deinit(allocator);

    const content = getFileContent(args.file, allocator) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("File not found: {s}\n", .{args.file});
        } else {
            std.debug.print("Error opening file '{s}': {s}\n", .{ args.file, @errorName(err) });
            return err;
        }
        return;
    };
    defer allocator.free(content);

    var parser = try Parser.initFromBuffer(allocator, content);
    defer parser.deinit();

    const document = try parser.parse();

    var printer = try Printer.init(allocator, document);
    const gql = try printer.getGql();
    std.debug.print("{s}", .{gql});
}
