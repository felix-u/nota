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
    NoColon,
    NoCurlyLeft,
    NoIteratorLabel,
    NoNodeName,
    UnexpectedCurlyLeft,
    UnexpectedKeyword,
    UnmatchedCurlyRight,
};

const Data = struct {
    lhs: u32 = 0,
    rhs: u32 = 0,
};

pub const Node = struct {
    tag: Tag = .root_node,
    data: Data = .{},

    const Tag = enum(u8) {
        // for symbol: lhs { ... }
        // lhs is the index into filters of the filter.
        // rhs is the index into childs of the for expression.
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

pub fn parseTreeFromToks(ctx: *parse.Context) !void {
    try parseTreeFromToksRecurse(ctx, 0, true);
}

pub fn parseTreeFromToksRecurse(
    ctx: *parse.Context,
    childs_i: u32,
    comptime in_root_node: bool,
) !void {
    const allocator = ctx.allocator;
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.symbol) => {
            if (it.inc()) |t2| switch (t2.kind) {
                '{' => {
                    tok = it.inc();
                    if (tok != null and tok.?.kind != '}') {
                        try recurseInBody(
                            ctx,
                            childs_i,
                            .node_decl_simple,
                            it.i - 2,
                        );
                    } else {
                        try appendChild(ctx, childs_i);
                        const node_name_i = it.i - 2;
                        try ctx.nodes.append(allocator, .{
                            .tag = .node_decl_simple,
                            .data = .{ .lhs = node_name_i, .rhs = 0 },
                        });
                    }
                },
                '=' => {
                    while (tok) |t3| : (tok = it.inc()) switch (t3.kind) {
                        ';' => break,
                        '{' => {
                            return log.err(ctx, Err.UnexpectedCurlyLeft, it.i);
                        },
                        else => {},
                    };

                    const var_name_i = it.i - 3;
                    try appendChild(ctx, childs_i);
                    try ctx.nodes.append(allocator, .{
                        .tag = .var_decl_literal,
                        .data = .{ .lhs = var_name_i, .rhs = it.i - 1 },
                    });
                },
                else => {
                    return log.err(ctx, token.Err.InvalidSyntax, it.i);
                },
            };
        },
        '{' => {
            return log.err(ctx, Err.NoNodeName, it.i);
        },
        '}' => {
            if (!in_root_node) return;
            return log.err(ctx, Err.UnmatchedCurlyRight, it.i);
        },
        @intFromEnum(token.Kind.@"for") => {
            try parseKeyword(ctx, childs_i, @enumFromInt(t.kind));
        },
        @intFromEnum(token.Kind.eof) => if (!in_root_node) {
            return log.err(ctx, Err.NoClosingCurly, it.i);
        },
        else => {},
    };
}

fn recurseInBody(
    ctx: *parse.Context,
    childs_i: u32,
    comptime tag: Node.Tag,
    lhs: u32,
) anyerror!void {
    const allocator = ctx.allocator;

    try appendChild(ctx, childs_i);

    const recurse_childs_i: u32 = @intCast(ctx.childs.items.len);

    try ctx.nodes.append(allocator, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = recurse_childs_i },
    });

    try parseTreeFromToksRecurse(ctx, recurse_childs_i, false);
}

fn appendChild(ctx: *parse.Context, childs_i: u32) !void {
    if (childs_i == ctx.childs.items.len) try ctx.childs.append(
        try std.ArrayList(u32).initCapacity(ctx.allocator, 1),
    );

    var list = &ctx.childs.items[childs_i];
    try list.append(@intCast(ctx.nodes.len));
}

fn parseKeyword(
    ctx: *parse.Context,
    childs_i: u32,
    keyword: token.Kind,
) anyerror!void {
    const allocator = ctx.allocator;
    _ = allocator;
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

    if (keyword == .@"for") {
        tok = it.inc() orelse return;
        if (tok.?.kind != @intFromEnum(token.Kind.symbol)) {
            return log.err(ctx, Err.NoIteratorLabel, it.i);
        }

        tok = it.inc() orelse return;
        if (tok.?.kind != ':') {
            return log.err(ctx, Err.NoColon, it.i);
        }

        tok = it.inc() orelse return;

        const lhs: u32 = @intCast(ctx.filters.items.len);
        try parseFilter(ctx);

        tok = it.peek();
        if (tok.?.kind != '{') return log.err(ctx, Err.NoCurlyLeft, it.i);

        tok = it.inc() orelse return;
        if (tok.?.kind == '}') return log.err(ctx, Err.EmptyBody, it.i);

        try recurseInBody(ctx, childs_i, .for_expr, lhs);

        return;
    }

    std.debug.print("UNIMPLEMENTED: {any}\n", .{keyword});
    @panic("UNIMPLEMENTED");
}

pub const Filter = struct {
    token_range: Data = .{},
    // A 0 index indicates that the filter terminates.
    next: FilterIndex = 0,

    const FilterIndex = u32;
};

pub const FilterList = std.ArrayList(Filter);
fn parseFilter(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t1| : (tok = it.inc()) {
        if (t1.kind != ')') continue;
        tok = it.inc();
        break;
    }
}

pub const TokenIterator = struct {
    toks: *std.MultiArrayList(token.Token) = undefined,
    i: u32 = undefined,

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
    ctx: *parse.Context,
    node_i: u32,
    indent_level: u32,
) !void {
    const node = ctx.nodes.get(node_i);
    const writer = ctx.writer;

    try writeIndent(writer, indent_level);
    try writer.print("{any} {any}\n", .{ node.tag, node.data });

    switch (node.tag) {
        .root_node => {},
        .node_decl_simple,
        .for_expr,
        => if (node.data.rhs == 0) return,
        else => return,
    }

    const childs = ctx.childs.items[node.data.rhs];

    for (childs.items) |i| {
        try printDebugRecurse(ctx, i, indent_level + 1);
    }
}

pub fn printDebug(ctx: *parse.Context) !void {
    const writer = ctx.writer;

    _ = try writer.write("NODES:\n");
    var node_i: usize = 0;
    while (node_i < ctx.nodes.len) : (node_i += 1) {
        try writer.print("{d}\t{any}\n", .{ node_i, ctx.nodes.get(node_i) });
    }

    try writer.writeByte('\n');

    _ = try writer.write("CHILDS:\n");
    var child_i: usize = 0;
    while (child_i < ctx.childs.items.len) : (child_i += 1) {
        try writer.print(
            "{d}\t{any}\n",
            .{ child_i, ctx.childs.items[child_i].items },
        );
    }

    try writer.writeByte('\n');

    _ = try writer.write("TREE:\n");
    try printDebugRecurse(ctx, 0, 0);
}

const AnsiClrState = enum {
    ansi_clr_disabled,
    ansi_clr_enabled,
};

pub fn printNicely(
    comptime ansi_clr: AnsiClrState,
    ctx: *parse.Context,
) !void {
    try printNicelyRecurse(ansi_clr, ctx, 0, 0, true);
}

pub fn printNicelyRecurse(
    comptime ansi_clr: AnsiClrState,
    ctx: *parse.Context,
    node_i: u32,
    indent_level: u32,
    comptime in_root_node: bool,
) !void {
    const clr = if (ansi_clr == .ansi_clr_enabled) true else false;
    const writer = ctx.writer;
    const node = ctx.nodes.get(node_i);

    try writeIndent(writer, indent_level);

    if (!in_root_node) switch (node.tag) {
        .root_node => unreachable,
        .for_expr => {
            if (clr) try ansi.set(writer, &.{ansi.fg_red});
            _ = try writer.write("for ");
            if (clr) try ansi.reset(writer);

            const iterator_name = ctx.lexeme(node.data.lhs);
            try writer.print("{s}: ", .{iterator_name});

            if (clr) try ansi.set(writer, &.{ansi.fg_magenta});
            const selector_i = node.data.lhs + 2;
            try printToOpenCurly(ctx, selector_i);
            if (clr) try ansi.reset(writer);

            _ = try writer.write(" {\n");
        },
        .node_decl_simple => {
            const node_name = ctx.lexeme(node.data.lhs);

            if (clr) try ansi.set(writer, &.{ansi.fmt_bold});
            try writer.print("{s}", .{node_name});
            if (clr) try ansi.reset(writer);

            _ = try writer.write(" {\n");
        },
        .var_decl_literal => {
            const var_name = ctx.lexeme(node.data.lhs);
            try writer.print("{s} = ", .{var_name});

            const literal = ctx.lexeme(node.data.rhs);
            const var_type: token.Kind =
                @enumFromInt(ctx.toks.items(.kind)[node.data.rhs]);
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

    const childs = ctx.childs.items[node.data.rhs];

    const childs_indent_level =
        if (in_root_node) indent_level else indent_level + 1;

    for (childs.items) |i| try printNicelyRecurse(
        ansi_clr,
        ctx,
        i,
        childs_indent_level,
        false,
    );

    if (print_closing_curly) {
        try writeIndent(writer, indent_level);
        _ = try writer.write("}\n");
    }
}

fn printToOpenCurly(ctx: *parse.Context, _tok_i: u32) !void {
    const buf_beg_i = ctx.toks.items(.beg_i)[_tok_i];

    var tok_i = _tok_i;
    while (ctx.toks.items(.kind)[tok_i] != '{') {
        tok_i += 1;
    }

    const buf_end_i = ctx.toks.items(.end_i)[tok_i - 1];

    _ = try ctx.writer.write(ctx.buf[buf_beg_i..buf_end_i]);
}
