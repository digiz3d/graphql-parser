const std = @import("std");
const tokenizer = @import("tokenizer.zig");

pub fn main() !void {
    // TODO: take input from params
    const filePath = "schema.graphql";

    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    const allocator = std.heap.page_allocator;

    // TODO: take any file size?
    const rawContent = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(rawContent);

    const content: [:0]u8 = try allocator.allocSentinel(u8, rawContent.len, 0);
    defer allocator.free(content);
    std.mem.copyForwards(u8, content, rawContent);

    var tok = tokenizer.Tokenizer.init(content);

    while (true) {
        const token = tok.getNextToken();
        if (token.tag == tokenizer.Token.Tag.eof) {
            break;
        }
        std.debug.print("Token: {s} \t ({s})\n", .{
            token.toString(),
            content[token.loc.start..token.loc.end],
        });
    }
}
