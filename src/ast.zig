// Note: should look at Zig data-oriented AST example.
//
// const Node = struct {
//     tag: Tag,
//     main_token: u32,
//     data: Data,
//
//     const Data = struct {
//         lhs: u32,
//         rhs: u32,
//     };
//
//     const Tag = enum {
//         var_decl_simple,
//         var_decl_typed,
//         var_decl_aligned,
//         if_simple,
//         if_full,
//         while_simple,
//         while_full,
//         ...
//     };
// };
//
// const NodeList = std.MultiArrayList(Node);

const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

const Writer = std.fs.File.Writer;

pub const Err = error{
    NoClosingCurly,
    NoNodeName,
    UnmatchedCurlyRight,
};

pub const NodeMap = std.StringHashMap(std.ArrayList(u32));

pub const Node = struct {
    decls: std.ArrayList(u32),
    childs: std.ArrayList(u32),
};

pub const Decl = struct {
    tok_name_i: u32,
    expr_i: u32,
};

pub const Expr = struct {
    tok_beg_i: u32 = undefined,
    tok_end_i: u32 = undefined,
};

pub fn parseToks(
    err_writer: Writer,
    set: *parse.Set,
    comptime in_body: bool,
) !void {
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            if (it.inc()) |t2| switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    try recurseInBody(err_writer, set);
                },
                '=' => {
                    // TODO: Parse decl and expression.
                    tok = it.inc();
                },
                else => {},
            };
        },
        '{' => {
            return log.reportErr(err_writer, Err.NoNodeName, set, t.beg_i);
        },
        '}' => {
            if (in_body) return;
            return log.reportErr(
                err_writer,
                Err.UnmatchedCurlyRight,
                set,
                t.beg_i,
            );
        },
        @intFromEnum(token.Kind.eof) => if (in_body) {
            return log.reportErr(err_writer, Err.NoClosingCurly, set, t.beg_i);
        },
        else => {},
    };
}

fn recurseInBody(err_writer: Writer, set: *parse.Set) anyerror!void {
    const allocator = set.allocator;

    const name_tok = set.toks.get(set.tok_it.i - 2);
    const name = name_tok.lexeme(set);

    const node_i: u32 = @intCast(set.nodes.len);
    try set.nodes.append(allocator, .{
        .decls = undefined,
        .childs = undefined,
    });

    const name_nodes = (try set.node_map.getOrPutValue(
        name,
        std.ArrayList(u32).init(allocator),
    )).value_ptr;

    try name_nodes.append(node_i);

    try parseToks(err_writer, set, true);
}

pub const TokenIterator = struct {
    toks: *std.MultiArrayList(token.Token),
    i: u32,

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
        if (self.i + 1 == self.toks.len) return .{};
        return self.toks.get(self.i + 1);
    }
};

pub fn printDebug(
    writer: Writer,
    set: *parse.Set,
    node_i: *u32,
) !void {
    node_i.* += 1;

    var it = set.node_map.keyIterator();
    while (it.next()) |i| {
        const name_num = set.node_map.get(i.*).?.items.len;
        std.debug.print("{d} of {s}\n", .{ name_num, i.* });
    }

    while (node_i.* < set.nodes.len) : (node_i.* += 1) {
        try writer.print("{any}\n", .{set.nodes.get(node_i.*)});
    }

    node_i.* -= 1;
}
