const std = @import("std");
const cast = std.math.lossyCast;
const log = @import("log.zig");
const parse = @import("parse.zig");
const token = @import("token.zig");

const type_map = std.ComptimeStringMap(token.Kind, .{
    .{ "bool", token.Kind.type_bool },
    .{ "date", token.Kind.type_date },
    .{ "num", token.Kind.type_num },
    .{ "str", token.Kind.type_str },
});

pub const Node = struct {
    token_name_idx: u32 = 0,
    expr_start_idx: u32 = 0,
    expr_end_idx: u32 = 0,
    node_children_start_idx: u32 = 0,
    node_children_end_idx: u32 = 0,
};
pub const NodeList = std.MultiArrayList(Node);

pub const Expr = struct {
    type: token.Kind = .unresolved,
    token_name_idx: u32 = 0,
    token_start_idx: u32 = 0,
};
pub const ExprList = std.MultiArrayList(Expr);

pub fn parseFromTokenList(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
) !void {
    const it = &set.token_it;
    it.set = set;

    var in_bounds = !it.atEnd();
    var appended_this = false;

    root: while (in_bounds) : (in_bounds = it.skip()) {
        // First token in loop is guaranteed to be either `@` or `}`.
        if (it.peek().token == .curly_right) {
            in_bounds = it.skip();
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
        in_bounds = it.skip();
        var this_node: Node = .{
            .token_name_idx = it.idx,
            .node_children_start_idx = cast(u32, set.node_list.len + 1),
        };
        in_bounds = it.skip();

        // Go to `;` to process node.
        this_node.expr_start_idx = cast(u32, set.expr_list.len);
        node: while (in_bounds and it.peek().token != .semicolon) {

            // Error case: floating `:`
            if (it.peek().token == .colon) {
                return log.reportError(errorWriter, log.SyntaxError.NoExprName, set, it.peek().idx);
            }

            // Error case: floating `=`
            if (it.peek().token == .equals) {
                return log.reportError(errorWriter, log.SyntaxError.AssignmentToNothing, set, it.peek().idx);
            }

            // Case: `name:maybe_type=expression`
            if (it.peek().token == .unresolved) {
                in_bounds = try parseDeclaration(allocator, errorWriter, set);
                this_node.expr_end_idx = cast(u32, set.expr_list.len);
                in_bounds = (it.idx < set.token_list.len);
                continue :node;
            }

            // `{`: Recurse in body.
            if (it.peek().token == .curly_left and it.peekNext() != null and it.peekNext().?.token != .curly_right) {
                in_bounds = it.skip();

                try set.node_list.append(allocator, this_node);
                appended_this = true;
                const this_node_idx = set.node_list.len - 1;
                var this_node_again = set.node_list.get(set.node_list.len - 1);
                try parseFromTokenList(allocator, errorWriter, set);
                this_node_again.node_children_end_idx = cast(u32, set.node_list.len);
                set.node_list.set(this_node_idx, this_node_again);

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

                // Node over.
                break :node;
            }
            // Ignore empty body.
            else if (it.peek().token == .curly_left and it.peekNext() != null and
                it.peekNext().?.token == .curly_right)
            {
                in_bounds = it.skip();
            }

            // The semicolon required before a new node or body end would've ended this loop, so:
            // `}` shouldn't be here if previous node wasn't `{` (empty body);
            // `@` shouldn't be here.
            if (it.peek().token == .at or
                (it.peek().token == .curly_right and it.peekLast() != null and it.peekLast().?.token != .curly_left))
            {
                return log.reportError(errorWriter, log.SyntaxError.NoSemicolonAfterNode, set, it.peek().idx);
            }
            in_bounds = it.skip();
        } // :node

        // Node over, so continue the outer loop.
        if (!appended_this) try set.node_list.append(allocator, this_node);
        continue :root;
    } // :root
}

fn parseDeclaration(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
) !bool {
    const it = &set.token_it;
    it.set = set;

    var this_expr: Expr = .{
        .type = .unresolved,
        .token_name_idx = it.idx,
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
                    it.peek().idx,
                );
                var this_token = it.peek();
                set.token_list.set(it.idx, .{
                    .token = .expr_name,
                    .idx = this_token.idx,
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
                    set.token_list.set(it.idx, .{
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
                const this_token_type = it.peek().token;
                switch (this_token_type) {
                    .unresolved, .str, .paren_left => {
                        if (this_token_type == .str) this_expr.type = .type_str;
                        in_bounds = try parseExpression(allocator, errorWriter, set, &this_expr);
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

fn parseExpression(
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    set: *parse.Set,
    expr: *Expr,
) !bool {
    const it = &set.token_it;
    it.set = set;

    try parse.ensureNotKeyword(
        errorWriter,
        &parse.types,
        log.SyntaxError.ExprIsTypeName,
        set,
        it.peek().idx,
        it.peek().idx,
    );

    expr.token_start_idx = it.idx;
    _ = it.skip();
    try set.expr_list.append(allocator, expr.*);
    return !it.atEnd();
}

pub const TokenIterator = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    const Self = @This();

    fn atEnd(self: *Self) bool {
        return (self.idx == self.set.token_list.len);
    }

    fn peek(self: *Self) token.Token {
        return self.set.token_list.get(self.idx);
    }

    fn next(self: *Self) ?token.Token {
        if (self.idx + 1 == self.set.token_list.len) return null;
        self.idx += 1;
        return self.peek();
    }

    fn peekNext(self: *Self) ?token.Token {
        if (self.idx == self.set.token_list.len - 1) return null;
        return self.set.token_list.get(self.idx + 1);
    }

    fn peekLast(self: *Self) ?token.Token {
        if (self.idx == 0) return null;
        return self.set.token_list.get(self.idx - 1);
    }

    pub fn skip(self: *Self) bool {
        if (self.idx + 1 == self.set.token_list.len) return false;
        self.idx += 1;
        return true;
    }
};

pub fn printDebugView(
    writer: std.fs.File.Writer,
    set: *parse.Set,
    level: usize,
    node_list_start: u32,
    node_list_end: u32,
) !void {
    var node_list_idx = node_list_start;
    while (node_list_idx < node_list_end) : (node_list_idx += 1) {
        const node = set.node_list.get(node_list_idx);
        const node_name = set.token_list.get(node.token_name_idx).lexeme(set);

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("{s} <<<\n", .{node_name});

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("{}\n", .{node});

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print("EXPR <\n", .{});
        var expr_idx = node.expr_start_idx;
        while (expr_idx < node.expr_end_idx) : (expr_idx += 1) {
            const expr = set.expr_list.get(expr_idx);

            for (0..level) |_| try writer.writeByte('\t');
            try writer.print("{s} = ", .{set.token_list.get(expr.token_name_idx).lexeme(set)});

            for (0..level) |_| try writer.writeByte('\t');
            try writer.print("{}\n", .{expr});
        }
        for (0..level) |_| try writer.writeByte('\t');
        try writer.print(">\n", .{});

        try printDebugView(writer, set, level + 1, node.node_children_start_idx, node.node_children_end_idx);
        if (node.node_children_end_idx > node.node_children_start_idx) {
            node_list_idx = node.node_children_end_idx - 1;
        }

        for (0..level) |_| try writer.writeByte('\t');
        try writer.print(">>> {s}\n", .{node_name});
    }
}
