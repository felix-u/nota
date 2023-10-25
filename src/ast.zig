const ansi = @import("ansi.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

const Writer = std.fs.File.Writer;

pub const Err = error{
    EmptyBody,
    EmptyFilter,
    EmptyInput,
    ExpectedArrow,
    FloatingIdent,
    NoBracketLeft,
    NoClosingCurly,
    NoColon,
    NoCurlyLeft,
    NoIteratorLabel,
    NoNodeName,
    NoSquareLeft,
    UnexpectedBracketRight,
    UnexpectedCurlyLeft,
    UnexpectedKeyword,
    UnexpectedPipe,
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
        // ( ... | lhs .. rhs | ... )
        filter_component,

        // lhs unused.
        // rhs is the index into childs_list of the filter.
        filter_group,

        // for lhs: rhs { rhs[1..]... }
        // lhs is the named filter capture.
        // rhs is the index into childs_list of the for expression. The first
        // child is actually the filter.
        for_expr,

        // [lhs..rhs]
        input,

        // lhs -> rhs
        // lhs is input node index and rhs the filter node index.
        iterator,

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
    try parseTreeFromToksRecurse(ctx, true);
}

pub fn parseTreeFromToksRecurse(
    ctx: *parse.Context,
    comptime in_root_node: bool,
) !void {
    const allocator = ctx.allocator;
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.ident) => if (it.inc()) |t2| switch (t2.kind) {
            '{' => {
                tok = it.inc();
                if (tok != null and tok.?.kind != '}') {
                    try recurseInBody(ctx, .node_decl_simple, it.i - 2);
                } else {
                    try appendNextNodeToChilds(ctx);
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
                try appendNextNodeToChilds(ctx);
                try ctx.nodes.append(allocator, .{
                    .tag = .var_decl_literal,
                    .data = .{ .lhs = var_name_i, .rhs = it.i - 1 },
                });
            },
            else => return log.err(ctx, token.Err.InvalidSyntax, it.i),
        },
        '{' => return log.err(ctx, Err.NoNodeName, it.i),
        '}' => {
            if (!in_root_node) return;
            return log.err(ctx, Err.UnmatchedCurlyRight, it.i);
        },
        @intFromEnum(token.Kind.@"for") => {
            try parseKeyword(ctx, @enumFromInt(t.kind));
        },
        @intFromEnum(token.Kind.eof) => if (!in_root_node) {
            return log.err(ctx, Err.NoClosingCurly, it.i);
        },
        else => {},
    };
}

fn recurseInBody(
    ctx: *parse.Context,
    comptime tag: Node.Tag,
    lhs: u32,
) anyerror!void {
    const it = &ctx.tok_it;
    const allocator = ctx.allocator;
    const prev_childs_i = ctx.childs_i;

    try appendNextNodeToChilds(ctx);
    ctx.childs_i = @intCast(ctx.childs.items.len);
    try ctx.nodes.append(allocator, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = ctx.childs_i },
    });

    if (tag == .for_expr) {
        try appendNextNodeToChilds(ctx);
        try parseIterator(ctx);

        var tok: ?token.Token = it.peek();
        if (tok.?.kind != '{') return log.err(ctx, Err.NoCurlyLeft, it.i);

        tok = it.inc() orelse return;
        if (tok.?.kind == '}') return log.err(ctx, Err.EmptyBody, it.i);
    }

    try parseTreeFromToksRecurse(ctx, false);

    ctx.childs_i = prev_childs_i;
}

fn parseIterator(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;

    const iterator_node_i = ctx.nodes.len;
    try ctx.nodes.append(ctx.allocator, .{ .tag = .iterator });

    const input_node_i: u32 = @intCast(ctx.nodes.len);
    try parseInput(ctx);
    ctx.nodes.items(.data)[iterator_node_i].lhs = input_node_i;

    if (it.peek().kind != @intFromEnum(token.Kind.arrow)) {
        return log.err(ctx, Err.ExpectedArrow, it.i);
    }

    const filter_group_node_i: u32 = @intCast(ctx.nodes.len);
    _ = it.inc();
    try parseFilterGroup(ctx);
    ctx.nodes.items(.data)[iterator_node_i].rhs = filter_group_node_i;
}

fn parseInput(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();
    if (tok.?.kind != '[') return log.err(ctx, Err.NoSquareLeft, it.i);

    tok = it.inc() orelse return;
    if (tok.?.kind == ']') return log.err(ctx, Err.EmptyInput, it.i);
    tok = it.inc();

    const tok_beg_i = it.i;
    while (tok) |t| : (tok = it.inc()) {
        if (t.kind == '{') return log.err(ctx, Err.UnexpectedCurlyLeft, it.i);
        if (t.kind == ']') break;
    }

    try ctx.nodes.append(ctx.allocator, .{
        .tag = .input,
        .data = .{ .lhs = tok_beg_i, .rhs = it.i },
    });

    tok = it.inc() orelse return;
}

fn parseFilterGroup(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;
    const prev_childs_i = ctx.childs_i;

    var tok: ?token.Token = it.peek();
    if (tok.?.kind != '(') return log.err(ctx, Err.NoBracketLeft, it.i);

    tok = it.inc() orelse return;
    if (tok.?.kind == ')') return log.err(ctx, Err.EmptyFilter, it.i);

    ctx.childs_i = @intCast(ctx.childs.items.len);
    try ctx.nodes.append(ctx.allocator, .{
        .tag = .filter_group,
        .data = .{ .rhs = ctx.childs_i },
    });

    group: while (tok) |_| : (tok = it.inc()) {
        const filter_component_beg_i = it.i;

        if (tok.?.kind == ')') {
            return log.err(ctx, Err.UnexpectedBracketRight, it.i);
        }

        tok = it.inc() orelse return;
        if (tok.?.kind == '|') return log.err(ctx, Err.UnexpectedPipe, it.i);

        toks: while (tok) |t2| : (tok = it.inc()) switch (t2.kind) {
            '|', ')' => break :toks,
            '{' => return log.err(ctx, Err.UnexpectedCurlyLeft, it.i),
            else => continue :toks,
        };

        try appendNextNodeToChilds(ctx);
        try ctx.nodes.append(ctx.allocator, .{
            .tag = .filter_component,
            .data = .{ .lhs = filter_component_beg_i, .rhs = it.i },
        });

        if (tok.?.kind == ')') break :group;
        if (tok.?.kind == '|') continue :group;
    }

    tok = it.inc() orelse return;
    ctx.childs_i = prev_childs_i;
}

fn appendNextNodeToChilds(ctx: *parse.Context) !void {
    if (ctx.childs_i == ctx.childs.items.len) try ctx.childs.append(
        try std.ArrayList(u32).initCapacity(ctx.allocator, 1),
    );

    var list = &ctx.childs.items[ctx.childs_i];
    try list.append(@intCast(ctx.nodes.len));
}

fn parseKeyword(ctx: *parse.Context, keyword: token.Kind) anyerror!void {
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

    if (keyword == .@"for") {
        tok = it.inc() orelse return;
        if (tok.?.kind != @intFromEnum(token.Kind.ident)) {
            return log.err(ctx, Err.NoIteratorLabel, it.i);
        }
        const lhs = it.i;

        tok = it.inc() orelse return;
        if (tok.?.kind != ':') return log.err(ctx, Err.NoColon, it.i);

        tok = it.inc() orelse return;
        try recurseInBody(ctx, .for_expr, lhs);

        return;
    }

    std.debug.print("UNIMPLEMENTED: {any}\n", .{keyword});
    @panic("UNIMPLEMENTED");
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
        .node_decl_simple, .for_expr, .filter_group => {
            if (node.data.rhs == 0) return;
        },
        else => return,
    }

    const childs = ctx.childs.items[node.data.rhs];
    for (childs.items) |i| try printDebugRecurse(ctx, i, indent_level + 1);
}

const AnsiClrState = enum { ansi_clr_disabled, ansi_clr_enabled };

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
        .filter_component,
        .filter_group,
        .input,
        .iterator,
        .root_node,
        => unreachable,
        .for_expr => {
            if (clr) try ansi.set(writer, &.{ansi.fg_red});
            _ = try writer.write("for ");
            if (clr) try ansi.reset(writer);

            const iterator_name = ctx.lexeme(node.data.lhs);
            try writer.print("{s}: ", .{iterator_name});

            if (clr) try ansi.set(writer, &.{ansi.fg_magenta});
            const childs = ctx.childs.items[node.data.rhs];
            const iterator_i = childs.items[0];
            try printIterator(ctx, iterator_i);
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
                .ident => try writer.print("{s}", .{literal}),
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
        .node_decl_simple, .for_expr => {
            print_closing_curly = true;
        },
        else => return,
    }

    const childs_indent_level =
        if (in_root_node) indent_level else indent_level + 1;

    var children_start_here: usize = 0;
    if (node.tag == .for_expr) children_start_here = 1;

    const childs = ctx.childs.items[node.data.rhs];
    for (childs.items[children_start_here..]) |i| try printNicelyRecurse(
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

fn printIterator(ctx: *parse.Context, iterator_i: u32) !void {
    const iterator = ctx.nodes.get(iterator_i);

    const input_i = iterator.data.lhs;
    try printInput(ctx, input_i);

    _ = try ctx.writer.write(" -> ");

    const filter_group_i = iterator.data.rhs;
    try printFilterGroup(ctx, filter_group_i);
}

fn printInput(ctx: *parse.Context, input_i: u32) !void {
    const writer = ctx.writer;
    const input = ctx.nodes.get(input_i);

    _ = try writer.writeByte('[');

    var tok_i = input.data.lhs;
    while (tok_i < input.data.rhs) : (tok_i += 1) {
        try writer.print(" {s} ", .{ctx.lexeme(tok_i)});
    }

    _ = try writer.writeByte(']');
}

fn printFilterGroup(ctx: *parse.Context, filter_group_i: u32) !void {
    const writer = ctx.writer;
    const filter_group = ctx.nodes.get(filter_group_i);
    const filter_components = ctx.childs.items[filter_group.data.rhs];

    _ = try writer.writeByte('(');

    var component_i: u32 = 0;
    while (component_i < filter_components.items.len) : (component_i += 1) {
        if (component_i > 0) _ = try writer.writeByte('|');

        const filter_component_i = filter_components.items[component_i];
        const component_data = ctx.nodes.items(.data)[filter_component_i];

        var tok_i: u32 = component_data.lhs;
        while (tok_i < component_data.rhs) : (tok_i += 1) {
            try writer.print(" {s} ", .{ctx.lexeme(tok_i)});
        }
    }

    _ = try writer.writeByte(')');
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
