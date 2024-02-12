const ansi = @import("ansi.zig");
const Context = @import("Context.zig");
const std = @import("std");
const token = @import("token.zig");

pub fn toks(ctx: *Context) !void {
    const writer = ctx.writer;

    _ = try writer.write("TOKENS:\n");

    for (0..ctx.toks.len) |i| {
        const tok = ctx.toks.get(i);
        const pos = ctx.filePosFromIndex(tok.beg_i);
        if (tok.kind < 128) try writer.print(
            "{d}:{d}\t{d}\t{s}\n",
            .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)) },
        ) else {
            const tok_kind: token.Kind = @enumFromInt(tok.kind);
            try writer.print(
                "{d}:{d}\t{d}\t{s}\t{}\n",
                .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok_kind },
            );
        }
    }
}

inline fn writeIndent(writer: std.fs.File.Writer, times: usize) !void {
    const indent_string = " " ** 4;
    for (times) |_| _ = try writer.write(indent_string);
}

pub fn debugAst(ctx: *Context) !void {
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
    try debugAstRecurse(ctx, 0, 0);
}

pub fn debugAstRecurse(ctx: *Context, node_i: u32, indent_level: u32) !void {
    const node = ctx.nodes.get(node_i);
    const writer = ctx.writer;

    try writeIndent(writer, indent_level);
    try writer.print("{any} {any}\n", .{ node.tag, node.data });

    switch (node.tag) {
        .root_node => {},
        .node_decl_simple => {
            if (node.data.rhs == 0) return;
        },
        else => return,
    }

    const childs = ctx.childs.items[node.data.rhs];
    for (childs.items) |i| try debugAstRecurse(ctx, i, indent_level + 1);
}

pub fn prettyAst(is_colour_on: bool, ctx: *Context) !void {
    switch (is_colour_on) {
        inline else => |inlined_is_colour_on| {
            try prettyAstRecurse(inlined_is_colour_on, ctx, 0, 0, true);
        },
    }
}

pub fn prettyAstRecurse(
    comptime is_colour_on: bool,
    ctx: *Context,
    node_i: u32,
    indent_level: u32,
    comptime in_root_node: bool,
) !void {
    const writer = ctx.writer;
    const node = ctx.nodes.get(node_i);

    try writeIndent(writer, indent_level);

    if (!in_root_node) switch (node.tag) {
        .root_node => unreachable,
        .node_decl_simple => {
            const node_name = ctx.lexeme(node.data.lhs);

            if (is_colour_on) try ansi.set(writer, &.{ansi.fmt_bold});
            try writer.print("{s}", .{node_name});
            if (is_colour_on) try ansi.reset(writer);

            _ = try writer.write(" {\n");
        },
        .reference => {
            try writer.print("{s};\n", .{ctx.lexeme(node.data.lhs)});
        },
        .var_decl_literal => {
            const var_name = ctx.lexeme(node.data.lhs);
            try writer.print("{s} = ", .{var_name});

            const literal = ctx.lexeme(node.data.rhs);
            const var_type: token.Kind =
                @enumFromInt(ctx.toks.items(.kind)[node.data.rhs]);
            switch (var_type) {
                .none, .chars, .eof => unreachable,
                .str => {
                    if (is_colour_on) try ansi.set(writer, &.{ansi.fg_cyan});
                    try writer.print("\"{s}\"", .{literal});
                    if (is_colour_on) try ansi.reset(writer);
                },
                .ident, .builtin => try writer.print("{s}", .{literal}),
            }

            _ = try writer.write("\n");
            return;
        },
    };

    if (node.tag == .node_decl_simple and node.data.rhs == 0) {
        try writeIndent(writer, indent_level);
        _ = try writer.write("}\n");
        return;
    }

    var print_closing_curly = false;
    switch (node.tag) {
        .root_node => {},
        .node_decl_simple => {
            print_closing_curly = true;
        },
        else => return,
    }

    const childs_indent_level =
        if (in_root_node) indent_level else indent_level + 1;

    const childs = ctx.childs.items[node.data.rhs];
    for (childs.items) |i| {
        try prettyAstRecurse(is_colour_on, ctx, i, childs_indent_level, false);
    }

    if (print_closing_curly) {
        try writeIndent(writer, indent_level);
        _ = try writer.write("}\n");
    }
}
