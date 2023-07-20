const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub const Err = error{
    NoNodeName,
};

pub const Node = struct {
    tok_name_i: u32 = undefined,
    expr_beg_i: u32 = undefined,
    expr_end_i: u32 = undefined,
    childs_beg_i: u32 = undefined,
    childs_end_i: u32 = undefined,
};

pub const Expr = struct {
    beg_i: u32 = undefined,
    end_i: u32 = undefined,
};

pub fn fromToksAlloc(allocator: std.mem.Allocator, errWriter: std.fs.File.Writer, set: *parse.Set) !void {
    const it = &set.tok_it;
    it.toks = &set.toks;

    var tok: ?token.Token = it.peek();

    toks: while (tok) |t| : (tok = it.inc()) {
        switch (t.kind) {
            .curly_left => {
                if (it.peekLast().kind != .symbol) return log.reportErr(errWriter, Err.NoNodeName, set, t.beg_i);

                const tok_name_i = it.i - 1;
                const expr_beg_i: u32 = @intCast(set.exprs.len);
                const childs_beg_i: u32 = @intCast(set.nodes.len);

                // TODO: Recurse properly.
                tok = it.inc();
                if (tok == null) break :toks;
                try fromToksAlloc(allocator, errWriter, set);
                if (tok == null) break :toks;

                const expr_end_i: u32 = @intCast(set.exprs.len);
                const childs_end_i: u32 = @intCast(set.nodes.len);

                try set.nodes.append(allocator, .{
                    .tok_name_i = tok_name_i,
                    .expr_beg_i = expr_beg_i,
                    .expr_end_i = expr_end_i,
                    .childs_beg_i = childs_beg_i,
                    .childs_end_i = childs_end_i,
                });
            },
            .curly_right => return,
            else => {},
        }
        continue :toks;
    }
}

pub const TokenIterator = struct {
    toks: *const std.MultiArrayList(token.Token) = undefined,
    i: u32 = 0,

    const Self = @This();

    pub fn inc(self: *Self) ?token.Token {
        self.i += 1;
        if (self.i == self.toks.len) return null;
        return self.toks.get(self.i);
    }

    pub fn peek(self: *Self) token.Token {
        return self.toks.get(self.i);
    }

    pub fn peekLast(self: *Self) token.Token {
        return if (self.i == 0) .{} else self.toks.get(self.i - 1);
    }

    pub fn peekNext(self: *Self) token.Token {
        return if (self.i + 1 == self.toks.len) .{} else self.toks.get(self.i + 1);
    }
};
