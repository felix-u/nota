const ansi = @import("ansi.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub fn toks(ctx: *parse.Context) !void {
    const log = @import("log.zig");
    const writer = ctx.writer;

    _ = try writer.write("TOKENS:\n");

    for (0..ctx.toks.len) |i| {
        const tok = ctx.toks.get(i);
        var pos: log.filePos = .{ .ctx = ctx, .i = tok.beg_i };
        pos.computeCoords();
        if (tok.kind < 128) try writer.print(
            "{d}:{d}\t{d}\t{s}\t{c}\n",
            .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok.kind },
        ) else {
            const tok_kind: token.Kind = @enumFromInt(tok.kind);
            try writer.print(
                "{d}:{d}\t{d}\t{s}\t{}\n",
                .{ pos.row, pos.col, i, ctx.lexeme(@intCast(i)), tok_kind },
            );
        }
    }
}

fn writeIndent(writer: std.fs.File.Writer, how_many_times: usize) !void {
    for (how_many_times) |_| _ = try writer.write(" " ** 4);
}

pub fn debugAst(ctx: *parse.Context) !void {
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

pub fn debugAstRecurse(
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
    for (childs.items) |i| try debugAstRecurse(ctx, i, indent_level + 1);
}

const AnsiClrState = enum { ansi_clr_disabled, ansi_clr_enabled };

pub fn prettyAst(
    comptime ansi_clr: AnsiClrState,
    ctx: *parse.Context,
) !void {
    try prettyAstRecurse(ansi_clr, ctx, 0, 0, true);
}

pub fn prettyAstRecurse(
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
    for (childs.items[children_start_here..]) |i| {
        try prettyAstRecurse(ansi_clr, ctx, i, childs_indent_level, false);
    }

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