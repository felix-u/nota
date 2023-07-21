const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub const Err = error{
    NoClosingCurly,
    NoNodeName,
    UnmatchedCurlyRight,
};

pub const Node = struct {
    tok_name_i: u32 = undefined,
    decl_beg_i: u32 = undefined,
    decl_end_i: u32 = undefined,
    childs_beg_i: u32 = undefined,
    childs_end_i: u32 = undefined,
};

pub const Decl = struct {
    tok_name_i: u32 = undefined,
    expr_i: u32 = undefined,
};

pub const Expr = struct {
    tok_beg_i: u32 = undefined,
    tok_end_i: u32 = undefined,
};

pub fn fromToksAlloc(
    allocator: std.mem.Allocator,
    err_writer: std.fs.File.Writer,
    set: *parse.Set,
    comptime in_body: bool,
) !void {
    const it = &set.tok_it;
    it.toks = &set.toks;

    var tok: ?token.Token = it.peek();

    toks: while (tok) |t| : (tok = it.inc()) {
        switch (t.kind) {
            .symbol => if (it.inc()) |t2| switch (t2.kind) {
                .curly_left => {
                    tok = it.inc();
                    try recurseInBody(allocator, err_writer, set);
                },
                .equals => {
                    var decl = Decl{ .tok_name_i = it.i - 1, .expr_i = @intCast(set.exprs.len) };
                    // TODO: Parse expression.
                    tok = it.inc();
                    try set.decls.append(allocator, decl);
                },
                else => {},
            },
            .curly_left => return log.reportErr(err_writer, Err.NoNodeName, set, t.beg_i),
            .curly_right => {
                if (in_body) return;
                return log.reportErr(err_writer, Err.UnmatchedCurlyRight, set, t.beg_i);
            },
            .eof => if (in_body) return log.reportErr(err_writer, Err.NoClosingCurly, set, t.beg_i),
            else => {},
        }
        continue :toks;
    }
}

fn recurseInBody(allocator: std.mem.Allocator, err_writer: std.fs.File.Writer, set: *parse.Set) anyerror!void {
    const node_to_fix_i = set.nodes.len;
    try set.nodes.append(allocator, .{
        .tok_name_i = set.tok_it.i - 2,
        .decl_beg_i = @intCast(set.decls.len),
        .childs_beg_i = @intCast(set.nodes.len + 1),
    });

    try fromToksAlloc(allocator, err_writer, set, true);

    set.nodes.items(.decl_end_i)[node_to_fix_i] = @intCast(set.decls.len);
    set.nodes.items(.childs_end_i)[node_to_fix_i] = @intCast(set.nodes.len);
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

pub fn printDebug(writer: std.fs.File.Writer, set: *parse.Set, indent: u32, node_i: *u32, decl_i: *u32) !void {
    const childs_end_i = set.nodes.items(.childs_end_i)[node_i.*];
    const decl_end_i = set.nodes.items(.decl_end_i)[node_i.*];
    node_i.* += 1;

    while (decl_i.* < decl_end_i) : (decl_i.* += 1) {
        const decl = set.decls.get(decl_i.*);
        const name_tok = set.toks.get(decl.tok_name_i);
        const name = set.buf[name_tok.beg_i..name_tok.end_i];

        _ = try writer.writeByteNTimes('\t', indent + 1);
        try writer.print("decl {d}: {s}\n", .{ decl_i.*, name });

        _ = try writer.writeByteNTimes('\t', indent + 1);
        try writer.print("{}\n", .{decl});
    }

    while (node_i.* < childs_end_i) : (node_i.* += 1) {
        const node = set.nodes.get(node_i.*);
        const name_tok = set.toks.get(node.tok_name_i);
        const name = set.buf[name_tok.beg_i..name_tok.end_i];

        _ = try writer.writeByteNTimes('\t', indent);
        try writer.print("node {d}: {s}\n", .{ node_i.*, name });

        _ = try writer.writeByteNTimes('\t', indent);
        try writer.print("{}\n", .{node});

        try printDebug(writer, set, indent + 1, node_i, decl_i);
    }

    node_i.* -= 1;
}
