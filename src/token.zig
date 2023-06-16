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
        if (@enumToInt(self.token) <= @enumToInt(Kind.characters)) {
            return set.buf[self.idx .. self.idx + 1];
        }
        var token_pos: parse.Set.BufIterator = .{ .set = set, .idx = self.idx };
        _ = if (self.token == .str) token_pos.incSkipString() else token_pos.incSkipSymbol();
        return set.buf[self.idx..token_pos.idx];
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
    const it = &set.buf_it;
    it.set = set;
    var in_bounds = true;

    root: while (it.next()) |_| {
        // Break into upper level if we've reached the end of the body.
        if (in_node_body and it.byte() == '}') {
            try set.token_list.append(allocator, .{
                .idx = it.idx,
                .token = .curly_right,
            });
            break :root;
        }

        // Don't parse quoted strings (@Node is a node, but not "@Node").
        for (quote_pairs) |quote| {
            if (it.byte() != quote) continue;
            in_bounds = it.inc();
            while (in_bounds and it.byte() != quote) : (in_bounds = it.inc()) {}
            in_bounds = it.inc();
            break;
        }

        // Parse node name.
        if (it.byte() != '@') continue;
        try set.token_list.append(allocator, .{
            .idx = it.idx,
            .token = .at,
        });
        in_bounds = it.inc();
        if (it.isValidSymbolChar()) {
            const name_start = it.idx;
            while (in_bounds and it.isValidSymbolChar()) : (in_bounds = it.inc()) {}
            var loc: log.filePosition = .{
                .filepath = set.filepath,
                .buf = set.buf,
                .idx = name_start,
            };
            try parse.ensureNotKeyword(
                &parse.reserved_all,
                log.SyntaxError.NameIsKeyword,
                set.buf[name_start..it.idx],
                &loc,
                errorWriter,
            );
            try set.token_list.append(allocator, .{
                .idx = name_start,
                .token = .node_name,
            });
        }

        // Parse node contents.
        in_bounds = it.incToNonWhitespace();
        node: while (in_bounds) : (in_bounds = it.incSkipWhitespace()) {
            // Symbols.

            // Quoted (in which case we know it's a string).
            // TODO: Skip over escaped quotes.
            for (quote_pairs) |quote| {
                if (it.byte() != quote) continue;
                in_bounds = it.inc();
                const symbol_start = it.idx;
                while (in_bounds and it.byte() != quote and it.nextByte() != '\n') : (in_bounds = it.inc()) {}
                if (it.nextByte() == '\n') {
                    var err_loc: log.filePosition = .{
                        .filepath = set.filepath,
                        .buf = set.buf,
                        .idx = it.idx,
                    };
                    err_loc.computeCoords();
                    return log.reportError(log.SyntaxError.StrNoClosingQuote, err_loc, errorWriter);
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
                while (in_bounds and it.isValidSymbolChar()) : (in_bounds = it.inc()) {}
                try set.token_list.append(allocator, .{
                    .idx = symbol_start,
                    .token = .unresolved,
                });
            }

            if (!in_bounds) break;

            // Single-character syntax.
            switch (it.byte()) {
                // If '@' was detected in this branch, it means there's a syntax error,
                // but as a favour to the AST we'll give it proper treatment anyway.
                '@' => {
                    in_bounds = it.dec();
                    continue :root;
                },
                ';', ':', '=', '(', ')', '[', ']', '{', '}', '.', '+', '-' => |byte| {
                    try set.token_list.append(allocator, .{
                        .idx = it.idx,
                        .token = @intToEnum(Kind, byte),
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
                    var err_loc: log.filePosition = .{
                        .filepath = set.filepath,
                        .buf = set.buf,
                        .idx = it.idx,
                    };
                    err_loc.computeCoords();
                    return log.reportError(log.SyntaxError.InvalidSyntax, err_loc, errorWriter);
                },
            } // switch(it.byte())
        } // :node
    } // :root
} // parse()
