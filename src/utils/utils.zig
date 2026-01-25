const std = @import("std");

const ArrayList = @import("std").ArrayList;
const Allocator = @import("std").mem.Allocator;

pub fn makeIndentation(indent: usize, allocator: Allocator) []const u8 {
    var spaces: ArrayList(u8) = .empty;
    const newIndent = indent * 2;
    for (0..newIndent) |_| {
        spaces.append(allocator, ' ') catch return "";
    }
    return spaces.toOwnedSlice(allocator) catch return "";
}

pub inline fn strEq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn newLineToBackslashN(alloc: Allocator, str: []const u8) []const u8 {
    var newStr: ArrayList(u8) = .empty;

    for (str) |char| {
        switch (char) {
            '\n', '\r' => {
                newStr.appendSlice(alloc, "\\n") catch return "";
            },
            else => newStr.append(alloc, char) catch return "",
        }
    }

    return newStr.toOwnedSlice(alloc) catch return "";
}

test "newLineToBackslashN" {
    const allocator = std.testing.allocator;
    const input = "hello\nworld";
    const expected = "hello\\nworld";
    const result = newLineToBackslashN(allocator, input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}

test "newLineToBackslashNMultiLine" {
    const allocator = std.testing.allocator;
    const input =
        \\"""
        \\lol
        \\test
        \\"""
    ;
    const expected = "\"\"\"\\nlol\\ntest\\n\"\"\"";
    const result = newLineToBackslashN(allocator, input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}

pub fn getFileContent(filePath: []const u8, allocator: Allocator) anyerror![:0]const u8 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    const stat = try file.stat();
    const rawContent = try file.readToEndAlloc(allocator, stat.size);
    defer allocator.free(rawContent);

    const content: [:0]u8 = try allocator.allocSentinel(u8, rawContent.len, 0);
    @memcpy(content, rawContent);

    return content;
}

pub fn normalizeLineEndings(allocator: Allocator, str: []const u8) []const u8 {
    var normalized: ArrayList(u8) = .empty;

    var i: usize = 0;
    while (i < str.len) {
        if (i + 1 < str.len and str[i] == '\r' and str[i + 1] == '\n') {
            normalized.append(allocator, '\n') catch return "";
            i += 2;
        } else if (str[i] == '\r') {
            normalized.append(allocator, '\n') catch return "";
            i += 1;
        } else {
            normalized.append(allocator, str[i]) catch return "";
            i += 1;
        }
    }

    return normalized.toOwnedSlice(allocator) catch return "";
}

test "normalizeLineEndings" {
    const allocator = std.testing.allocator;
    const input = "hello\r\nworld\r\ntest\r";
    const expected = "hello\nworld\ntest\n";
    const result = normalizeLineEndings(allocator, input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings(expected, result);
}
