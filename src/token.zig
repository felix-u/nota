const std = @import("std");
const ascii = std.ascii;
const ast = @import("ast.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");

pub const Kind = enum(u8) {
    // Single-character syntax.
    paren_left = '(',
    paren_right = ')',
    square_left = '[',
    square_right = ']',
    curly_left = '{',
    curly_right = '}',
    at = '@',
    colon = ':',
    semicolon = ';',
    equals = '=',
    dot = '.',
    plus = '+',
    minus = '-',

    characters = 128,

    // Type of literals.
    str,

    // Type specifier as provided by the user.
    type_infer, // Resolved in AST stage.
    type_bool, // Resolved in AST stage.
    type_date, // Resolved in AST stage.
    type_num, // Resolved in AST stage.
    type_str, // Resolved in AST stage.

    // Symbols.
    unresolved,
    node_name,
    expr_name, // Resolved in AST stage.

    eof,
};

pub const Token = struct {
    token: Kind,
    idx: u32,

    pub fn lexeme(self: Token, set: *parse.Set) []const u8 {
        if (@intFromEnum(self.token) <= @intFromEnum(Kind.characters)) {
            return set.buf[self.idx .. self.idx + 1];
        }
        var buf_it: BufIterator = .{ .set = set, .idx = self.idx };
        _ = if (self.token == .str) buf_it.skipString() else buf_it.skipSymbol();
        return set.buf[self.idx..buf_it.idx];
    }
    pub fn lastByteIdx(self: Token, set: *parse.Set) u32 {
        return self.idx + std.math.lossyCast(u32, self.lexeme(set).len) - 1;
    }
};

pub const TokenList = std.MultiArrayList(Token);

const quote_pairs = "\"'`";

pub fn parseFromBufAlloc(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
    comptime in_node_body: bool,
) !void {
    var in_bounds = true;
    const it = &set.buf_it;
    it.set = set;

    root: while (in_bounds) : (in_bounds = it.skip()) {
        // Break into upper level if we've reached the end of the body.
        if (in_node_body and it.peek() == '}') {
            try set.token_list.append(allocator, .{
                .idx = it.idx,
                .token = .curly_right,
            });
            break :root;
        }

        // Don't parse quoted strings (@Node is a node, but not "@Node").
        for (quote_pairs) |quote| {
            if (it.peek() != quote) continue;
            if (it.next()) |_| {
                while (it.next()) |c| {
                    if (c == quote) break;
                }
                if (it.next()) |_| break;
            }
        }

        // Parse node name.
        if (it.peek() != '@') continue;
        try set.token_list.append(allocator, .{
            .idx = it.idx,
            .token = .at,
        });
        if (it.next() == null) return;
        if (it.isValidSymbolChar()) {
            const name_start = it.idx;
            while (it.isValidSymbolChar() and it.next() != null) {}
            try parse.ensureNotKeyword(
                errorWriter,
                &parse.reserved_all,
                log.SyntaxError.NameIsKeyword,
                set,
                name_start,
                it.idx,
            );
            try set.token_list.append(allocator, .{
                .idx = name_start,
                .token = .node_name,
            });
        }

        // Parse node contents.
        node: while (in_bounds) : (in_bounds = it.skipWhitespace()) {
            // Symbols.

            // Quoted (in which case we know it's a string).
            // TODO: Skip over escaped quotes.
            for (quote_pairs) |quote| {
                if (it.peek() != quote) continue;
                if (it.next() == null) return;
                const symbol_start = it.idx;
                while (in_bounds and
                    it.peek() != quote and
                    it.peekNext() != null and
                    it.peekNext().? != '\n') : (in_bounds = it.skip())
                {}
                if (it.peekNext() != null and it.peekNext().? == '\n') {
                    return log.reportError(errorWriter, log.SyntaxError.StrNoClosingQuote, set, it.idx);
                }
                try set.token_list.append(allocator, .{
                    .idx = symbol_start,
                    .token = .str,
                });
                continue :node;
            }

            // Unquoted.
            if (it.isValidSymbolChar()) {
                const symbol_start = it.idx;
                while (in_bounds and it.isValidSymbolChar()) : (in_bounds = it.skip()) {}
                try set.token_list.append(allocator, .{
                    .idx = symbol_start,
                    .token = .unresolved,
                });
            }

            // Single-character syntax.
            switch (it.peek()) {
                // If '@' was detected in this branch, it means there's a syntax error,
                // but as a favour to the AST we'll give it proper treatment anyway.
                '@' => {
                    _ = it.last();
                    continue :root;
                },
                ';', ':', '=', '(', ')', '[', ']', '{', '}', '.', '+', '-' => |byte| {
                    try set.token_list.append(allocator, .{
                        .idx = it.idx,
                        .token = @enumFromInt(Kind, byte),
                    });
                    if (byte == '{') {
                        _ = try parseFromBufAlloc(allocator, errorWriter, set, true);
                    }
                    // If '}' was detected in this branch, it has no matching left curly bracket,
                    // but as a favour to the AST we'll give it proper treatment anyway.
                    if (byte == '}') continue :node;
                    if (byte == ';') continue :root;
                    continue :node;
                },
                else => |byte| {
                    if (ascii.isWhitespace(byte)) continue :node;
                    return log.reportError(errorWriter, log.SyntaxError.InvalidSyntax, set, it.idx);
                },
            } // switch(it.peek())
        } // :node
    } // :root
} // parse()

pub const BufIterator = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    const Self = @This();

    pub fn peek(self: *Self) u8 {
        return self.set.buf[self.idx];
    }

    pub fn peekNext(self: *Self) ?u8 {
        if (self.idx == self.set.buf.len - 1) return null;
        return self.set.buf[self.idx + 1];
    }

    pub fn last(self: *Self) ?u8 {
        if (self.idx == 0) return null;
        self.idx -= 1;
        return self.peek();
    }

    pub fn next(self: *Self) ?u8 {
        self.idx += 1;
        if (self.idx == self.set.buf.len) return null;
        return self.peek();
    }

    pub fn skip(self: *Self) bool {
        if (self.idx + 1 == self.set.buf.len) return false;
        self.idx += 1;
        return true;
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
        if (!ascii.isWhitespace(self.peek())) return true;
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
        const c = self.peek();
        return ascii.isAlphanumeric(c) or (c == '_') or (c == '-');
    }

    pub fn getBytes(self: *Self) []const u8 {
        var end_idx: u32 = self.idx;
        while (end_idx < self.set.buf.len and isValidSymbolChar(self)) : (end_idx += 1) {}
        return self.set.buf[self.idx..end_idx];
    }
};
