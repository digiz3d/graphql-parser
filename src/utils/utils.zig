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

pub fn newLineToBackslashN(allocator: Allocator, str: []const u8) []const u8 {
    var newStr = ArrayList(u8).init(allocator);

    for (str) |char| {
        switch (char) {
            '\n', '\r' => {
                newStr.appendSlice("\\n") catch return "";
            },
            else => newStr.append(char) catch return "",
        }
    }

    return newStr.toOwnedSlice() catch return "";
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
