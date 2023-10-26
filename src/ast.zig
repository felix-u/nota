const ansi = @import("ansi.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

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
    const it = &ctx.tok_it;

    var tok: ?token.Token = it.peek();

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
                    '{' => {
                        return log.err(ctx, Err.UnexpectedCurlyLeft, it.i);
                    },
                    else => {},
                };

                const var_name_i = it.i - 3;
                try appendNodeToChilds(ctx, .{
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
    const prev_childs_i = ctx.childs_i;

    try appendNextNodeToChilds(ctx);
    ctx.childs_i = @intCast(ctx.childs.items.len);
    try appendNode(ctx, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = ctx.childs_i },
    });

    if (tag == .for_expr) {
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

    try appendNodeToChilds(ctx, .{ .tag = .iterator });

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
    const input_beg_i = it.i;
    if (tok.?.kind == ']') return log.err(ctx, Err.EmptyInput, it.i);
    tok = it.inc();

    while (tok) |t| : (tok = it.inc()) {
        if (t.kind == '{') return log.err(ctx, Err.UnexpectedCurlyLeft, it.i);
        if (t.kind == ']') break;
    }

    try appendNode(ctx, .{
        .tag = .input,
        .data = .{ .lhs = input_beg_i, .rhs = it.i },
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
    try appendNode(ctx, .{
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

        try appendNodeToChilds(ctx, .{
            .tag = .filter_component,
            .data = .{ .lhs = filter_component_beg_i, .rhs = it.i },
        });

        if (tok.?.kind == ')') break :group;
        if (tok.?.kind == '|') continue :group;
    }

    tok = it.inc() orelse return;
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
