const ansi = @import("ansi.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

const Writer = std.fs.File.Writer;

pub const Err = error{
    EmptyBody,
    FloatingSymbol,
    NoClosingCurly,
    NoIteratorLabel,
    NoNodeName,
    UnexpectedCurlyLeft,
    UnexpectedKeyword,
    UnmatchedCurlyRight,
};

pub const Node = struct {
    tag: Tag = .root_node,
    data: Data = .{},

    const Data = struct {
        lhs: u32 = 0,
        rhs: u32 = 0,
    };

    const Tag = enum(u8) {
        // for lhs... { ... }
        // lhs is the index into filter_list of the filter.
        // rhs is the index into childs_list of the for expression.
        for_expr,

        // lhs { }
        // rhs is the index into childs_list of the node, or 0 if there are no
        // children.
        node_decl_simple,

        // lhs unused.
        // rhs is the index into childs_list of the node, or 0 if there are no
        // children.
        root_node,

        // rhs is the index of a string, date, or number.
        // lhs = rhs
        var_decl_literal,
    };
};

pub const NodeList = std.MultiArrayList(Node);

pub const Childs = std.ArrayList(std.ArrayList(u32));

pub fn parseTreeFromToks(
    err_writer: Writer,
    set: *parse.Set,
) !void {
    try parseTreeFromToksRecurse(err_writer, set, 0, true);
}

pub fn parseTreeFromToksRecurse(
    err_writer: Writer,
    set: *parse.Set,
    childs_i: u32,
    comptime in_root_node: bool,
) !void {
    const allocator = set.allocator;
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            if (it.inc()) |t2| switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    if (tok != null and tok.?.kind != '}') {
                        try recurseInBody(
                            err_writer,
                            set,
                            childs_i,
                            .node_decl_simple,
                            it.i - 2,
                        );
                    } else {
                        try appendChild(set, childs_i);
                        const node_name_i = it.i - 2;
                        try set.nodes.append(allocator, .{
                            .tag = .node_decl_simple,
                            .data = .{ .lhs = node_name_i, .rhs = 0 },
                        });
                    }
                },
                '=' => {
                    while (tok) |t3| : (tok = it.inc()) switch (t3.kind) {
                        ';' => break,
                        '{' => return log.reportErr(
                            err_writer,
                            Err.UnexpectedCurlyLeft,
                            set,
                            it.i,
                        ),
                        else => {},
                    };

                    const var_name_i = it.i - 3;
                    try appendChild(set, childs_i);
                    try set.nodes.append(allocator, .{
                        .tag = .var_decl_literal,
                        .data = .{ .lhs = var_name_i, .rhs = it.i - 1 },
                    });
                },
                else => return log.reportErr(
                    err_writer,
                    token.Err.InvalidSyntax,
                    set,
                    it.i,
                ),
            };
        },
        '{' => {
            return log.reportErr(err_writer, Err.NoNodeName, set, it.i);
        },
        '}' => {
            if (!in_root_node) return;
            return log.reportErr(
                err_writer,
                Err.UnmatchedCurlyRight,
                set,
                it.i,
            );
        },
        @intFromEnum(token.Kind.@"for") => try parseKeyword(
            err_writer,
            set,
            childs_i,
            @enumFromInt(t.kind),
        ),
        @intFromEnum(token.Kind.eof) => if (!in_root_node) {
            return log.reportErr(err_writer, Err.NoClosingCurly, set, it.i);
        },
        else => {},
    };
}

fn recurseInBody(
    err_writer: Writer,
    set: *parse.Set,
    childs_i: u32,
    comptime tag: Node.Tag,
    lhs: u32,
) anyerror!void {
    const allocator = set.allocator;

    try appendChild(set, childs_i);

    const recurse_childs_i: u32 = @intCast(set.childs.items.len);

    try set.nodes.append(allocator, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = recurse_childs_i },
    });

    try parseTreeFromToksRecurse(err_writer, set, recurse_childs_i, false);
}

fn appendChild(set: *parse.Set, childs_i: u32) !void {
    if (childs_i == set.childs.items.len) try set.childs.append(
        try std.ArrayList(u32).initCapacity(set.allocator, 1),
    );

    var list = &set.childs.items[childs_i];
    try list.append(@intCast(set.nodes.len));
}

fn parseKeyword(
    err_writer: Writer,
    set: *parse.Set,
    childs_i: u32,
    keyword: token.Kind,
) anyerror!void {
    const allocator = set.allocator;
    _ = allocator;
    const it = &set.tok_it;

    var tok: ?token.Token = it.peek();

    if (keyword == .@"for") {
        tok = it.inc();
        const lhs = it.i;
        tok = it.inc();
        if (tok == null) return;
        while (tok) |_| : (tok = it.inc()) switch (tok.?.kind) {
            ':' => while (tok) |t2| : (tok = it.inc()) switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    if (tok != null and tok.?.kind != '}') try recurseInBody(
                        err_writer,
                        set,
                        childs_i,
                        .for_expr,
                        lhs,
                    ) else return log.reportErr(
                        err_writer,
                        Err.EmptyBody,
                        set,
                        it.i,
                    );
                },
                else => continue,
            },
            else => return log.reportErr(
                err_writer,
                Err.NoIteratorLabel,
                set,
                it.i,
            ),
        };
        return;
    }

    std.debug.print("UNIMPLEMENTED: {any}\n", .{keyword});
    @panic("UNIMPLEMENTED");
}

fn parseFilter(
    err_writer: Writer,
    set: *parse.Set,
    comptime stop_char: u8,
) !void {
    const allocator = set.allocator;
    _ = allocator;
    const it = &set.tok_it;

    const filter_i = it.i;

    var tok: ?token.Token = it.peek();

    while (tok) |_| : (tok = it.inc()) switch (tok.?.kind) {
        stop_char => return,
        else => continue,
    };

    return log.reportErr(err_writer, Err.NoFilterEnd, set, filter_i);
}

pub const TokenIterator = struct {
    toks: *std.MultiArrayList(token.Token),
    i: u32,

    const Self = @This();

    pub fn inc(self: *Self) ?token.Token {
        self.i += 1;
        if (self.i >= self.toks.len) return null;
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

fn writeIndent(writer: Writer, how_many_times: usize) !void {
    for (how_many_times) |_| _ = try writer.write(" " ** 4);
}

pub fn printDebugRecurse(
    writer: Writer,
    set: *parse.Set,
    node_i: u32,
    indent_level: u32,
) !void {
    const node = set.nodes.get(node_i);

    try writeIndent(writer, indent_level);
    try writer.print("{any} {any}\n", .{ node.tag, node.data });

    switch (node.tag) {
        .root_node => {},
        .node_decl_simple,
        .for_expr,
        => if (node.data.rhs == 0) return,
        else => return,
    }

    const childs = set.childs.items[node.data.rhs];

    for (childs.items) |i| {
        try printDebugRecurse(writer, set, i, indent_level + 1);
    }
}

pub fn printDebug(writer: Writer, set: *parse.Set) !void {
    _ = try writer.write("NODES:\n");
    var node_i: usize = 0;
    while (node_i < set.nodes.len) : (node_i += 1) {
        try writer.print("{d}\t{any}\n", .{ node_i, set.nodes.get(node_i) });
    }

    try writer.writeByte('\n');

    _ = try writer.write("CHILDS:\n");
    var child_i: usize = 0;
    while (child_i < set.childs.items.len) : (child_i += 1) {
        try writer.print(
            "{d}\t{any}\n",
            .{ child_i, set.childs.items[child_i].items },
        );
    }

    try writer.writeByte('\n');

    _ = try writer.write("TREE:\n");
    try printDebugRecurse(writer, set, 0, 0);
}

const AnsiClrState = enum {
    ansi_clr_disabled,
    ansi_clr_enabled,
};

pub fn printNicely(
    writer: Writer,
    comptime ansi_clr: AnsiClrState,
    set: *parse.Set,
) !void {
    try printNicelyRecurse(writer, ansi_clr, set, 0, 0, true);
}

pub fn printNicelyRecurse(
    writer: Writer,
    comptime ansi_clr: AnsiClrState,
    set: *parse.Set,
    node_i: u32,
    indent_level: u32,
    comptime in_root_node: bool,
) !void {
    const clr = if (ansi_clr == .ansi_clr_enabled) true else false;

    const node = set.nodes.get(node_i);

    try writeIndent(writer, indent_level);

    if (!in_root_node) switch (node.tag) {
        .for_expr => {
            if (clr) try ansi.set(writer, &.{ansi.fg_red});
            _ = try writer.write("for ");
            if (clr) try ansi.reset(writer);

            const iterator_name = set.toks.get(node.data.lhs).lexeme(set);
            try writer.print("{s}: ", .{iterator_name});

            if (clr) try ansi.set(writer, &.{ansi.fg_magenta});
            const selector_i = node.data.lhs + 2;
            try printToOpenCurly(writer, set, selector_i);
            if (clr) try ansi.reset(writer);

            _ = try writer.write(" {\n");
        },
        .node_decl_simple => {
            const node_name = set.toks.get(node.data.lhs).lexeme(set);

            if (clr) try ansi.set(writer, &.{ansi.fmt_bold});
            try writer.print("{s}", .{node_name});
            if (clr) try ansi.reset(writer);

            _ = try writer.write(" {\n");
        },
        .root_node => unreachable,
        .var_decl_literal => {
            const var_name = set.toks.get(node.data.lhs).lexeme(set);
            try writer.print("{s} = ", .{var_name});
            const literal = set.toks.get(node.data.rhs).lexeme(set);

            const var_type: token.Kind =
                @enumFromInt(set.toks.items(.kind)[node.data.rhs]);
            switch (var_type) {
                .str => {
                    if (clr) try ansi.set(writer, &.{ansi.fg_cyan});
                    try writer.print("\"{s}\"", .{literal});
                    if (clr) try ansi.reset(writer);
                },
                .num, .true, .false => {
                    if (clr) try ansi.set(
                        writer,
                        &.{ ansi.fg_cyan, ansi.fmt_bold },
                    );
                    try writer.print("{s}", .{literal});
                    if (clr) try ansi.reset(writer);
                },
                .symbol => {
                    try writer.print("{s}", .{literal});
                },
                else => unreachable,
            }

            _ = try writer.write(";\n");

            return;
        },
    };

    if (node.tag != .root_node and node.data.rhs == 0) {
        try writeIndent(writer, indent_level);
        _ = try writer.write("}\n");
        return;
    }

    var print_closing_curly = false;
    switch (node.tag) {
        .root_node => {},
        .node_decl_simple,
        .for_expr,
        => print_closing_curly = true,
        else => return,
    }

    const childs = set.childs.items[node.data.rhs];

    const childs_indent_level =
        if (in_root_node) indent_level else indent_level + 1;

    for (childs.items) |i| try printNicelyRecurse(
        writer,
        ansi_clr,
        set,
        i,
        childs_indent_level,
        false,
    );

    if (print_closing_curly) {
        try writeIndent(writer, indent_level);
        _ = try writer.write("}\n");
    }
}

fn printToOpenCurly(writer: Writer, set: *parse.Set, _tok_i: u32) !void {
    const buf_beg_i = set.toks.items(.beg_i)[_tok_i];

    var tok_i = _tok_i;
    while (set.toks.items(.kind)[tok_i] != '{') {
        tok_i += 1;
    }

    const buf_end_i = set.toks.items(.end_i)[tok_i - 1];

    _ = try writer.write(set.buf[buf_beg_i..buf_end_i]);
}
