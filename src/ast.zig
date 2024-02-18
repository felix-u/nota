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
        // `(node lhs rhs...)`
        // lhs is the token index of the node name.
        // rhs is the node index into childs_list of the node, or 0 if there
        // are no children.
        node_decl_simple,

        // lhs is the token index of the identifier name.
        // rhs unused.
        reference,

        // lhs unused.
        // rhs is the node index into childs_list of the node, or 0 if there
        // are no children.
        root_node,

        // `(const lhs rhs)`
        // lhs is the token index of the variable name.
        // rhs is the token index of a string, date, or number.
        const_decl,
    };
};

pub const NodeList = std.MultiArrayList(Node);

pub const Childs = std.ArrayList(std.ArrayList(u32));

pub fn parseTreeFromToks(
    ctx: *Context,
    comptime meta: struct { in_root_node: bool = true },
) anyerror!void {
    const it = &ctx.tok_it;
    var tok = it.peek();
    outer: while (!tok.isEof()) : (tok = it.inc()) switch (tok.kind) {
        '(' => {
            tok = it.inc();
            switch (tok.kind) {
                @intFromEnum(token.Kind.keyword_node) => {
                    tok = it.inc();
                    tok = it.inc();
                    try recurseInBody(ctx, .node_decl_simple, it.i - 1);
                    continue :outer;
                },
                @intFromEnum(token.Kind.keyword_const) => {
                    tok = it.inc();
                    const const_name_i = it.i;
                    tok = it.inc();
                    try appendNodeToChilds(ctx, .{
                        .tag = .const_decl,
                        .data = .{ .lhs = const_name_i, .rhs = it.i },
                    });
                    tok = it.inc();
                    continue :outer;
                },
                ')' => return ctx.err("empty expression", .{}),
                else => return ctx.err("DEBUG '{s}'", .{ctx.lexeme(it.i)}),
            }
        },
        ')' => {
            if (!meta.in_root_node) return;
            return ctx.err("')' here does not match any '('", .{});
        },
        else => return ctx.err(
            "expected '(' or end of file, but found '{s}'",
            .{ctx.lexeme(it.i)},
        ),
    };
    if (!meta.in_root_node) return ctx.err("unexpected end of file", .{});
}

fn recurseInBody(ctx: *Context, comptime tag: Node.Tag, lhs: u32) !void {
    const prev_childs_i = ctx.childs_i;

    try appendNextNodeToChilds(ctx);
    ctx.childs_i = @intCast(ctx.childs.items.len);
    try appendNode(ctx, .{
        .tag = tag,
        .data = .{ .lhs = lhs, .rhs = ctx.childs_i },
    });

    try parseTreeFromToks(ctx, .{ .in_root_node = false });

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
