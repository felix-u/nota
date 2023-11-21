const ansi = @import("ansi.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub const Err = error{
    EmptyBody,
    EmptyFilter,
    EmptyInput,
    FloatingIdent,
    NoIteratorLabel,
    NoNodeName,
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
        // ( ... | lhs .. rhs | ... )
        // // TODO: ^ ->
        // // lhs is the Op.
        // // rhs is the index into childs_list of the expr inputs.
        expr,

        // lhs unused.
        // rhs is the index into childs_list of the filter.
        filter,

        // for lhs: rhs { rhs[1..]... }
        // lhs is 0 if implicit or UNIMPLEMENTED the index into the iterator
        // label.
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

        // lhs;
        // rhs unused.
        reference,

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
    const it = &ctx.tok_it;

    var tok: ?token.Token = try it.peek();

    while (tok) |t| : (tok = it.inc()) switch (t.kind) {
        @intFromEnum(token.Kind.ident) => if (it.inc()) |t2| switch (t2.kind) {
            '{' => {
                tok = it.inc();
                if (tok != null and tok.?.kind != '}') {
                    try recurseInBody(ctx, .node_decl_simple, it.i - 2);
                } else {
                    const node_name_i = it.i - 2;
                    try appendNodeToChilds(ctx, .{
                        .tag = .node_decl_simple,
                        .data = .{ .lhs = node_name_i, .rhs = 0 },
                    });
                }
            },
            '=' => {
                while (tok) |t3| : (tok = it.inc()) switch (t3.kind) {
                    ';' => break,
                    '{' => return ctx.errChar(log.Err.UnexpectedChar, '{'),
                    else => {},
                };

                const var_name_i = it.i - 3;
                try appendNodeToChilds(ctx, .{
                    .tag = .var_decl_literal,
                    .data = .{ .lhs = var_name_i, .rhs = it.i - 1 },
                });
            },
            ';' => {
                const ref_i = it.i - 1;
                try appendNodeToChilds(ctx, .{
                    .tag = .reference,
                    .data = .{ .lhs = ref_i },
                });
            },
            else => return ctx.err(token.Err.InvalidSyntax),
        },
        '{' => return ctx.err(Err.NoNodeName),
        '}' => {
            if (!in_root_node) return;
            return ctx.err(Err.UnmatchedCurlyRight);
        },
        @intFromEnum(token.Kind.@"for") => {
            try parseKeyword(ctx, @enumFromInt(t.kind));
        },
        @intFromEnum(token.Kind.eof) => if (!in_root_node) {
            return ctx.errChar(log.Err.ExpectedChar, '}');
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
    const prev_childs_i = ctx.childs_i;

    try appendNextNodeToChilds(ctx);
    ctx.childs_i = @intCast(ctx.childs.items.len);
    try appendNode(ctx, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = ctx.childs_i },
    });

    if (tag == .for_expr) {
        try parseIterator(ctx);

        try ctx.expectChar('{');

        const tok: ?token.Token = it.inc();
        if (tok.?.kind == '}') return ctx.err(Err.EmptyBody);
    }

    try parseTreeFromToksRecurse(ctx, false);

    ctx.childs_i = prev_childs_i;
}

fn parseIterator(ctx: *parse.Context) !void {
    const iterator_node_i = ctx.nodes.len;

    try appendNodeToChilds(ctx, .{ .tag = .iterator });

    const input_node_i: u32 = @intCast(ctx.nodes.len);
    try parseInput(ctx);
    ctx.nodes.items(.data)[iterator_node_i].lhs = input_node_i;

    const filter_node_i: u32 = @intCast(ctx.nodes.len);
    try parseFilter(ctx);
    ctx.nodes.items(.data)[iterator_node_i].rhs = filter_node_i;
}

fn parseInput(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;
    const input_beg_i = it.i;

    try ctx.expectCharNot('{');
    try ctx.expectCharNot('|');

    var tok: ?token.Token = it.inc() orelse return;

    while (tok != null and tok.?.kind != '|') : (tok = it.inc()) {
        try ctx.expectCharNot('{');
        try ctx.expectCharNot('}');
    }

    try appendNode(ctx, .{
        .tag = .input,
        .data = .{ .lhs = input_beg_i, .rhs = it.i },
    });
}

fn parseFilter(ctx: *parse.Context) !void {
    const it = &ctx.tok_it;
    const prev_childs_i = ctx.childs_i;

    ctx.childs_i = @intCast(ctx.childs.items.len);
    try appendNode(ctx, .{
        .tag = .filter,
        .data = .{ .rhs = ctx.childs_i },
    });

    try ctx.expectCharNot('{');

    var tok: ?token.Token = it.inc();
    filter: while (tok) |_| : (tok = it.inc()) {
        it.i -= 1;
        try ctx.expectChar('|');
        tok = it.inc() orelse return;
        try ctx.expectCharNot('|');

        const expr_beg_i = it.i;
        expr: while (tok) |t| : (tok = it.inc()) {
            if (t.kind != '|' and t.kind != '{') continue :expr;

            try appendNodeToChilds(ctx, .{
                .tag = .expr,
                .data = .{ .lhs = expr_beg_i, .rhs = it.i },
            });
            break :expr;
        }

        if ((try it.peek()).kind == '{') break :filter;
    }

    ctx.childs_i = prev_childs_i;
}

pub inline fn appendNode(ctx: *parse.Context, node: Node) !void {
    try ctx.nodes.append(ctx.allocator, node);
}

fn appendNextNodeToChilds(ctx: *parse.Context) !void {
    if (ctx.childs_i == ctx.childs.items.len) try ctx.childs.append(
        try std.ArrayList(u32).initCapacity(ctx.allocator, 1),
    );

    const list = &ctx.childs.items[ctx.childs_i];
    try list.append(@intCast(ctx.nodes.len));
}

inline fn appendNodeToChilds(ctx: *parse.Context, node: Node) !void {
    try appendNextNodeToChilds(ctx);
    try appendNode(ctx, node);
}

fn parseKeyword(ctx: *parse.Context, keyword: token.Kind) anyerror!void {
    const it = &ctx.tok_it;

    var tok: ?token.Token = try it.peek();

    if (keyword == .@"for") {
        tok = it.inc() orelse return;
        const lhs = 0;
        try recurseInBody(ctx, .for_expr, lhs);
        return;
    }

    std.debug.print("UNIMPLEMENTED: {any}\n", .{keyword});
    @panic("UNIMPLEMENTED");
}

pub const TokenIterator = struct {
    ctx: *parse.Context = undefined,
    i: u32 = undefined,

    const Self = @This();

    pub fn inc(self: *Self) ?token.Token {
        self.i += 1;
        if (self.i >= self.ctx.toks.len) return null;
        return self.ctx.toks.get(self.i);
    }

    pub fn peek(self: *Self) !token.Token {
        if (self.i == self.ctx.toks.len) {
            return log.err(self.ctx, log.Err.UnexpectedEOF, self.i - 1);
        }
        return self.ctx.toks.get(self.i);
    }

    pub fn peekLast(self: *Self) token.Token {
        return if (self.i == 0) .{} else self.ctx.toks.get(self.i - 1);
    }

    pub fn peekNext(self: *Self) token.Token {
        if (self.i + 1 == self.ctx.toks.len) return .{};
        return self.ctx.toks.get(self.i + 1);
    }
};
