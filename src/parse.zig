const std = @import("std");
const ascii = std.ascii;
const ast = @import("ast.zig");
const log = @import("log.zig");
const token = @import("token.zig");

pub const types = [_][]const u8{
    "bool",
    "date",
    "num",
    "str",
};

pub const values = [_][]const u8{
    "true",
    "false",
};

pub const matches = [_][]const u8{
    "up",
    "down",
    "to",
    "through",
};

pub const reserved_all = types ++ values ++ matches;

pub fn ensureNotKeyword(
    comptime reserved_list: []const []const u8,
    comptime err: log.SyntaxError,
    str: []const u8,
    loc: *log.filePosition,
    errorWriter: std.fs.File.Writer,
) !void {
    inline for (reserved_list) |keyword| {
        if (std.mem.eql(u8, str, keyword)) {
            loc.*.computeCoords();
            return log.reportError(err, loc.*, errorWriter);
        }
    }
}

pub const Set = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    buf_it: BufIterator = .{},
    token_list: token.TokenList = .{},
    node_list: ast.NodeList = .{},
    expr_list: ast.ExprList = .{},

    pub const BufIterator = struct {
        set: *Set = undefined,
        idx: u32 = 0,
        const Self = @This();

        pub fn byte(self: *Self) u8 {
            return self.set.buf[self.idx];
        }
        pub fn byteNext(self: *Self) ?u8 {
            if (self.idx == self.set.buf.len - 1) return null;
            return self.set.buf[self.idx + 1];
        }
        pub fn last(self: *Self) ?u8 {
            if (self.idx == 0) return null;
            self.idx -= 1;
            return self.byte();
        }
        pub fn next(self: *Self) ?u8 {
            self.idx += 1;
            if (self.idx == self.set.buf.len) return null;
            return self.byte();
        }
        pub fn skipNonWhitespace(self: *Self) bool {
            return while (self.next()) |c| {
                if (ascii.isWhitespace(c)) break true;
            } else false;
        }
        pub fn skipString(self: *Self) bool {
            return while (self.next()) |c| {
                if (!self.isValidSymbolChar() and c != ' ' and c != '\t') break true;
            } else false;
        }
        pub fn skipSymbol(self: *Self) bool {
            return while (self.next()) |_| {
                if (!self.isValidSymbolChar()) break true;
            } else false;
        }
        pub fn skipWhitespace(self: *Self) bool {
            return while (self.next()) |c| {
                if (!ascii.isWhitespace(c)) break true;
            } else false;
        }
        pub fn toNonWhitespace(self: *Self) bool {
            if (!ascii.isWhitespace(self.byte())) return true;
            return while (self.next()) |c| {
                if (!ascii.isWhitespace(c)) break true;
            } else false;
        }
        pub fn toValidSymbolChar(self: *Self) bool {
            if (self.isValidSymbolChar()) return true;
            return while (self.next()) |_| {
                if (self.isValidSymbolChar()) break true;
            } else false;
        }
        pub fn isValidSymbolChar(self: *Self) bool {
            const c = self.byte();
            return ascii.isAlphanumeric(c) or (c == '_') or (c == '-');
        }
        pub fn getBytes(self: *Self) []const u8 {
            var end_idx: u32 = self.idx;
            while (end_idx < self.set.buf.len and isValidSymbolChar(self)) : (end_idx += 1) {}
            return self.set.buf[self.idx..end_idx];
        }
    };
};
