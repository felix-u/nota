const ansi = @import("ansi.zig");
const Context = @import("Context.zig");
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
        // lhs { }
        // rhs is the index into childs_list of the node, or 0 if there are no
        // children.
        node_decl_simple,

        // lhs points to identifier name
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

pub inline fn parseTreeFromToks(ctx: *Context) !void {
    try parseTreeFromToksRecurse(ctx, true);
}

pub fn parseTreeFromToksRecurse(
    ctx: *Context,
    comptime in_root_node: bool,
) anyerror!void {
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
        @intFromEnum(token.Kind.eof) => {
            if (!in_root_node) return ctx.err(
                .token,
                "unexpected end of file; '}}' required to end node",
                .{},
            );
        },
        else => {},
    };
}

fn recurseInBody(ctx: *Context, comptime tag: Node.Tag, lhs: u32) !void {
    const prev_childs_i = ctx.childs_i;

    try appendNextNodeToChilds(ctx);
    ctx.childs_i = @intCast(ctx.childs.items.len);
    try appendNode(ctx, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = ctx.childs_i },
    });

    try parseTreeFromToksRecurse(ctx, false);

    ctx.childs_i = prev_childs_i;
}

pub inline fn appendNode(ctx: *Context, node: Node) !void {
    try ctx.nodes.append(ctx.allocator, node);
}

fn appendNextNodeToChilds(ctx: *Context) !void {
    if (ctx.childs_i == ctx.childs.items.len) try ctx.childs.append(
        try std.ArrayList(u32).initCapacity(ctx.allocator, 1),
    );

    const list = &ctx.childs.items[ctx.childs_i];
    try list.append(@intCast(ctx.nodes.len));
}

inline fn appendNodeToChilds(ctx: *Context, node: Node) !void {
    try appendNextNodeToChilds(ctx);
    try appendNode(ctx, node);
}

pub const TokenIterator = struct {
    ctx: *Context = undefined,
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
