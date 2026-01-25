const std = @import("std");
const Allocator = std.mem.Allocator;

const Document = @import("ast/document.zig").Document;
const getDocumentGql = @import("printer/graphql.zig").getDocumentGql;
const getDocumentText = @import("printer/text.zig").getDocumentText;

pub const Printer = struct {
    allocator: Allocator,
    document: Document,
    currentIndent: usize,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: Allocator, document: Document) !Printer {
        return Printer{
            .allocator = allocator,
            .document = document,
            .currentIndent = 0,
            .buffer = .empty,
        };
    }

    pub fn deinit(self: *Printer) void {
        self.buffer.deinit();
    }

    pub fn getGql(self: *Printer) ![]u8 {
        self.buffer.clearAndFree(self.allocator);
        try getDocumentGql(self);
        return self.buffer.toOwnedSlice(self.allocator);
    }

    pub fn getText(self: *Printer) ![]u8 {
        self.buffer.clearAndFree(self.allocator);
        try getDocumentText(self);
        return self.buffer.toOwnedSlice(self.allocator);
    }

    pub fn append(self: *Printer, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    pub fn appendByte(self: *Printer, byte: u8) !void {
        try self.buffer.append(self.allocator, byte);
    }

    pub fn newLine(self: *Printer) !void {
        try self.appendByte('\n');
        for (0..self.currentIndent) |_| {
            try self.appendByte(' ');
        }
    }

    pub fn openBrace(self: *Printer) !void {
        try self.append(" {");
        self.indent();
    }

    pub fn closeBrace(self: *Printer) !void {
        self.unindent();
        try self.newLine();
        try self.appendByte('}');
    }

    pub fn indent(self: *Printer) void {
        self.currentIndent += 2;
    }

    pub fn unindent(self: *Printer) void {
        self.currentIndent -= 2;
    }
};
