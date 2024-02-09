const ansi = @import("ansi.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

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

    var tok = it.peek();
    while (!tok.isEof()) : (tok = it.inc()) switch (tok.kind) {
        @intFromEnum(token.Kind.ident) => {
            tok = it.inc();
            switch (tok.kind) {
                '{' => {
                    tok = it.inc();
                    if (tok.kind != '}') {
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
                    while (!tok.isEof()) : (tok = it.inc()) switch (tok.kind) {
                        ';' => break,
                        '{' => return ctx.err(
                            .token,
                            "unexpected '{{' in variable declaration",
                            .{},
                        ),
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
                else => return ctx.err(
                    .token,
                    "expected '{{', '=', or ';' following identifier '{s}'," ++
                        " but found '{s}'",
                    .{ ctx.lexeme(it.i - 1), ctx.lexeme(it.i) },
                ),
            }
        },
        '{' => return ctx.err(.token, "expected node name before body", .{}),
        '}' => {
            if (!in_root_node) return;
            return ctx.err(.token, "'}}' here does not match any '{{'", .{});
        },
        @intFromEnum(token.Kind.@"for") => {
            try parseKeyword(ctx, @enumFromInt(tok.kind));
        },
        @intFromEnum(token.Kind.eof) => if (!in_root_node) return ctx.err(
            .token,
            "unexpected end of file; '}}' required to end node",
            .{},
        ),
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

        if (it.peek().kind != '{')
            return ctx.err(.token, "expected '{{' to begin body", .{});

        const tok = it.inc();
        if (tok.kind == '}') return ctx.err(.token, "unexpected '}}'; " ++
            "body of for expression cannot be empty", .{});
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

    var tok = it.peek();

    if (tok.kind == '{')
        return ctx.err(.token, "filter required before start of body", .{});
    if (tok.kind == '|')
        return ctx.err(.token, "input required before filter", .{});

    tok = it.inc();
    while (!tok.isEof() and tok.kind != '|') : (tok = it.inc()) {
        if (tok.kind == '{') return ctx.err(
            .token,
            "input must be filtered at least once",
            .{},
        );
        if (tok.kind == '}')
            return ctx.err(.token, "'}}' invalid here", .{});
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

    var tok = it.inc();
    if (tok.kind == '{')
        return ctx.err(.token, "empty filter; '{{' invalid here", .{});

    filter: while (!tok.isEof()) : (tok = it.inc()) {
        it.i -= 1;
        if (it.peek().kind != '|')
            return ctx.err(.token, "expected '|' to begin filter", .{});
        tok = it.inc();
        if (tok.kind == '|') return ctx.err(
            .token,
            "empty filter; did you forget to add it between '|' and '|'?",
            .{},
        );

        const expr_beg_i = it.i;
        expr: while (!tok.isEof()) : (tok = it.inc()) {
            if (tok.kind == '}') return ctx.err(
                .token,
                "'}}' invalid in filter (are you missing an opening '{{'?)",
                .{},
            );

            if (tok.kind != '|' and tok.kind != '{') continue :expr;

            try appendNodeToChilds(ctx, .{
                .tag = .expr,
                .data = .{ .lhs = expr_beg_i, .rhs = it.i },
            });
            break :expr;
        }

        if (tok.kind == '{') break :filter;
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
    var tok = it.peek();
    switch (keyword) {
        .@"for" => {
            tok = it.inc();
            const lhs = 0;
            try recurseInBody(ctx, .for_expr, lhs);
            return;
        },
        else => {
            try ctx.err_writer.print("UNIMPLEMENTED: {any}\n", .{keyword});
            @panic("UNIMPLEMENTED");
        },
    }
}

pub const TokenIterator = struct {
    ctx: *parse.Context = undefined,
    i: u32 = undefined,

    const Self = @This();

    pub fn inc(self: *Self) token.Token {
        self.i += 1;
        if (self.i >= self.ctx.toks.len)
            return .{ .kind = @intFromEnum(token.Kind.eof) };
        return self.ctx.toks.get(self.i);
    }

    pub fn peek(self: *Self) token.Token {
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
