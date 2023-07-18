const std = @import("std");
const cast = std.math.lossyCast;
const log = @import("log.zig");
const parse = @import("parse.zig");
const token = @import("token.zig");

pub fn typeName(tok_kind: token.Kind) []const u8 {
    return switch (tok_kind) {
        .type_infer => "infer",
        .type_bool => "bool",
        .type_date => "date",
        .type_num => "num",
        .type_str => "str",
        else => @panic("This function only works with .type_xx"),
    };
}

const type_map = std.ComptimeStringMap(token.Kind, .{
    .{ typeName(.type_bool), .type_bool },
    .{ typeName(.type_date), .type_date },
    .{ typeName(.type_num), .type_num },
    .{ typeName(.type_str), .type_str },
});

pub const Node = struct {
    tok_name_i: u32 = 0,
    expr_beg_i: u32 = 0,
    expr_end_i: u32 = 0,
    childs_beg_i: u32 = 0,
    childs_end_i: u32 = 0,
};
pub const NodeList = std.MultiArrayList(Node);

pub const Expr = struct {
    type: token.Kind = .unresolved,
    tok_name_i: u32 = 0,
    tok_beg_i: u32 = 0,
    tok_end_i: u32 = 0,
};
pub const ExprList = std.MultiArrayList(Expr);

pub fn parseFromTokenList(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
    comptime in_body: bool,
) !void {
    const it = &set.tok_it;
    it.set = set;

    var appended_this = false;

    var in_bounds = !it.atEnd();
    while (in_bounds) : (in_bounds = it.skip()) {
        // First token in loop is guaranteed to be either `@` or `}`.
        if (it.peek().token == .curly_right) {
            _ = it.next();
            break;
        }

        // Error case: name doesn't immediately follow `@`.
        if (it.peekNext()) |next_token| {
            if (next_token.token != .node_name) return log.reportError(
                errorWriter,
                log.SyntaxError.NoNodeName,
                set,
                it.peek().idx,
            );
        }

        // Get node name.
        _ = it.next();
        var this_node: Node = .{
            .tok_name_i = it.idx,
            .childs_beg_i = cast(u32, set.nodes.len + 1),
        };
        _ = it.next();

        // Go to `;` to process node.
        this_node.expr_beg_i = cast(u32, set.exprs.len);
        node: while (!it.atEnd() and it.peek().token != .semicolon) {
            if (it.peek().token == .colon) {
                return log.reportError(errorWriter, log.SyntaxError.NoExprName, set, it.peek().idx);
            }

            if (it.peek().token == .equals) {
                return log.reportError(errorWriter, log.SyntaxError.AssignmentToNothing, set, it.peek().idx);
            }

            // Case: `name:maybe_type=expression`
            if (it.peek().token == .unresolved) {
                _ = try parseDeclaration(allocator, errorWriter, set);
                this_node.expr_end_i = cast(u32, set.exprs.len);
                _ = (it.idx < set.toks.len);
                continue :node;
            }

            // `{`: Recurse in body.
            if (it.peek().token == .curly_left and it.peekNext() != null and it.peekNext().?.token != .curly_right) {
                _ = it.next();

                try set.nodes.append(allocator, this_node);
                appended_this = true;
                const this_node_i = set.nodes.len - 1;
                var this_node_again = set.nodes.get(set.nodes.len - 1);
                try parseFromTokenList(allocator, errorWriter, set, true);
                this_node_again.childs_end_i = cast(u32, set.nodes.len);
                set.nodes.set(this_node_i, this_node_again);

                // Error case: token after body end is not a semicolon.
                if (it.peek().token != .semicolon) {
                    if (it.peek().token == .at) return log.reportError(
                        errorWriter,
                        log.SyntaxError.NoSemicolonAfterNode,
                        set,
                        it.peek().idx,
                    );

                    return log.reportError(errorWriter, log.SyntaxError.NoSemicolonAfterBody, set, it.peek().idx);
                }

                break :node;
            }

            // Ignore empty body.
            else if (it.peek().token == .curly_left and it.peekNext() != null and
                it.peekNext().?.token == .curly_right)
            {
                _ = it.next();
            }

            // The semicolon required before a new node or body end would've ended this loop, so:
            // `}` shouldn't be here if previous node wasn't `{` (empty body);
            // `@` shouldn't be here.
            if (it.peek().token == .at or
                (it.peek().token == .curly_right and it.peekLast() != null and it.peekLast().?.token != .curly_left))
            {
                return log.reportError(errorWriter, log.SyntaxError.NoSemicolonAfterNode, set, it.peek().idx);
            }
            _ = it.next();
        } // :node

        if (in_body and it.atEnd() and it.peek().token != .curly_right) {
            return log.reportError(errorWriter, log.SyntaxError.NoRightCurly, set, it.peek().idx);
        }

        if (!appended_this) try set.nodes.append(allocator, this_node);
    }
}

fn parseDeclaration(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
) !bool {
    const it = &set.tok_it;
    it.set = set;

    var this_expr: Expr = .{
        .type = .unresolved,
        .tok_name_i = it.idx,
    };

    var in_bounds = !it.atEnd();
    expr: while (in_bounds) : (in_bounds = it.skip()) {
        switch (it.peek().token) {
            // Expression name: `name:...`
            .unresolved => {
                try parse.ensureNotKeyword(
                    errorWriter,
                    &parse.reserved_all,
                    log.SyntaxError.NameIsKeyword,
                    set,
                    it.peek().idx,
                    it.peek().lastByteIdx(set) + 1,
                );
                set.toks.set(it.idx, .{
                    .token = .expr_name,
                    .idx = it.peek().idx,
                });
                continue :expr;
            },
            // Type syntax: `name : type`
            .colon => {
                // Resolve type in '...:type=...'.
                in_bounds = it.skip();
                if (it.peek().token == .unresolved) {
                    const type_string = it.peek().lexeme(set);
                    this_expr.type = type_map.get(type_string) orelse {
                        // Error case: invalid type specifier.
                        return log.reportError(
                            errorWriter,
                            log.SyntaxError.InvalidTypeSpecifier,
                            set,
                            it.peek().idx,
                        );
                    };
                    var this_token = it.peek();
                    set.toks.set(it.idx, .{
                        .token = this_expr.type,
                        .idx = this_token.idx,
                    });
                    continue :expr;
                }
                // Error case: inferred type uses `=`, not `:=`
                if (it.peek().token == .equals) {
                    return log.reportError(errorWriter, log.SyntaxError.NoTypeAfterColon, set, it.peek().idx);
                }
            },
            .equals => {
                in_bounds = it.skip();
                // Expression is `...=unresolved`, where `unresolved` is either
                // an expression name, a date, or a number.
                if (this_expr.type == .unresolved) this_expr.type = .type_infer;
                const this_tok_type = it.peek().token;
                switch (this_tok_type) {
                    .unresolved, .str, .paren_left => {
                        if (this_tok_type == .str) this_expr.type = .type_str;
                        if (this_tok_type == .paren_left) {
                            in_bounds = try parseExpr(allocator, errorWriter, set, &this_expr, true);
                        } else {
                            in_bounds = try parseExpr(allocator, errorWriter, set, &this_expr, false);
                        }
                        break :expr;
                    },
                    else => {
                        // Error case: no valid expression after `=`
                        return log.reportError(errorWriter, log.SyntaxError.NoExpr, set, it.peek().idx);
                    },
                }
            },
            else => {
                return log.reportError(errorWriter, log.SyntaxError.Unimplemented, set, it.peek().idx);
            },
        } // switch (it.peek().token)
    } // :expr

    return in_bounds;
}

fn parseExpr(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
    expr: *Expr,
    comptime in_paren: bool,
) !bool {
    const it = &set.tok_it;
    it.set = set;

    expr.tok_beg_i = it.idx;

    var in_bounds = !it.atEnd();
    while (in_bounds) : (in_bounds = it.skip()) {
        _ = switch (it.peek().token) {
            .paren_left => {
                in_bounds = it.skip();
                in_bounds = try parseExpr(allocator, errorWriter, set, expr, true);
            },
            .paren_right => {
                if (!in_paren) return log.reportError(errorWriter, log.SyntaxError.NoLeftParen, set, it.peek().idx);
                break;
            },
            else => {
                try parse.ensureNotKeyword(
                    errorWriter,
                    &parse.types,
                    log.SyntaxError.ExprIsTypeName,
                    set,
                    it.peek().idx,
                    it.peek().lastByteIdx(set) + 1,
                );
                break;
            },
        };
    }

    _ = it.skip();

    expr.tok_end_i = it.idx;

    if (in_paren) _ = it.last();

    try set.exprs.append(allocator, expr.*);
    return !it.atEnd();
}

pub const TokenIterator = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    const Self = @This();

    fn atEnd(self: *Self) bool {
        return (self.idx == self.set.toks.len - 1);
    }

    fn peek(self: *Self) token.Token {
        return self.set.toks.get(self.idx);
    }

    fn next(self: *Self) ?token.Token {
        if (self.idx + 1 == self.set.toks.len) return null;

        const this_token = self.peek();
        self.idx += 1;
        return this_token;
    }

    fn last(self: *Self) ?token.Token {
        if (self.idx == 0) return null;

        const this_token = self.peek();
        self.idx -= 1;
        return this_token;
    }

    fn peekNext(self: *Self) ?token.Token {
        if (self.idx + 1 == self.set.toks.len) return null;
        return self.set.toks.get(self.idx + 1);
    }

    fn peekLast(self: *Self) ?token.Token {
        if (self.idx == 0) return null;
        return self.set.toks.get(self.idx - 1);
    }

    pub fn skip(self: *Self) bool {
        if (self.idx + 1 == self.set.toks.len) return false;
        self.idx += 1;
        return true;
    }
};

pub fn printNicely(
    writer: std.fs.File.Writer,
    set: *parse.Set,
    level: usize,
    nodes_beg: u32,
    nodes_end: u32,
) !void {
    var nodes_i = nodes_beg;
    while (nodes_i < nodes_end) : (nodes_i += 1) {
        const node = set.nodes.get(nodes_i);
        const node_name = set.toks.get(node.tok_name_i).lexeme(set);

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("@{s}\n", .{node_name});

        var expr_i = node.expr_beg_i;
        while (expr_i < node.expr_end_i) : (expr_i += 1) {
            const expr_decl = set.exprs.get(expr_i);
            const expr_name = set.toks.get(expr_decl.tok_name_i).lexeme(set);

            // TODO
            const tok_end_i = if (expr_i == node.expr_end_i - 1)
                expr_decl.tok_beg_i + 1
            else
                set.exprs.get(expr_i + 1).tok_name_i;

            for (0..level + 1) |_| try writer.writeByte('\t');
            try writer.print("{s}: {s} = ", .{ expr_name, typeName(expr_decl.type) });
            for (expr_decl.tok_beg_i..tok_end_i) |tok_i| {
                try writer.print("{s}", .{set.toks.get(tok_i).lexeme(set)});
            }
            try writer.writeByte('\n');
        }

        try printNicely(writer, set, level + 1, node.childs_beg_i, node.childs_end_i);
        if (node.childs_end_i > node.childs_beg_i) {
            nodes_i = node.childs_end_i - 1;
        }
    }
}

pub fn printDebugView(
    writer: std.fs.File.Writer,
    set: *parse.Set,
    level: usize,
    nodes_beg: u32,
    nodes_end: u32,
) !void {
    var nodes_i = nodes_beg;
    while (nodes_i < nodes_end) : (nodes_i += 1) {
        const node = set.nodes.get(nodes_i);
        const node_name = set.toks.get(node.tok_name_i).lexeme(set);

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("{s} <<<\n", .{node_name});

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("{}\n", .{node});

        for (0..level) |_| try writer.writeByte('\t');
        _ = try writer.write("EXPR <\n");
        var expr_i = node.expr_beg_i;
        while (expr_i < node.expr_end_i) : (expr_i += 1) {
            const expr = set.exprs.get(expr_i);

            for (0..level) |_| try writer.writeByte('\t');
            try writer.print("{s} = ", .{set.toks.get(expr.tok_name_i).lexeme(set)});

            for (0..level) |_| try writer.writeByte('\t');
            try writer.print("{}\n", .{expr});
        }
        for (0..level) |_| try writer.writeByte('\t');
        _ = try writer.write(">\n");

        try printDebugView(writer, set, level + 1, node.childs_beg_i, node.childs_end_i);
        if (node.childs_end_i > node.childs_beg_i) {
            nodes_i = node.childs_end_i - 1;
        }

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print(">>> {s}\n", .{node_name});
    }
}
