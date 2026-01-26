const std = @import("std");
pub const Merger = @import("merge.zig").Merger;
pub const Parser = @import("parser.zig").Parser;
pub const Printer = @import("printer.zig").Printer;
pub const Document = @import("ast/document.zig").Document;
pub const getFileContent = @import("utils/utils.zig").getFileContent;

test {
    std.testing.refAllDecls(@This());
}
