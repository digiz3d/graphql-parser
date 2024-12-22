const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    // TODO: take input from params
    const filePath = "schema.graphql";

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const content = try getFileContent(filePath, allocator);
    defer allocator.free(content);

    var parser = Parser.init();
    var document = try parser.parse(content, allocator);
    document.printAST(0);
}

fn getFileContent(filePath: []const u8, allocator: Allocator) ![:0]const u8 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    // TODO: take any file size?
    const rawContent = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(rawContent);

    const content: [:0]u8 = try allocator.allocSentinel(u8, rawContent.len, 0);
    @memcpy(content, rawContent);

    return content;
}
