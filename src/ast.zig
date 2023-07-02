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

    root: while (in_bounds) : (in_bounds = it.inc()) {
        // First token in loop is guaranteed to be either `@` or `}`.
        if (it.getToken().token == .curly_right) {
            in_bounds = it.inc();
            break;
        }

        // Error case: name doesn't immediately follow `@`.
        if (it.nextToken().token != .node_name) {
            return log.reportError(errorWriter, log.SyntaxError.NoNodeName, set, it.getToken().idx);
        }

        // Get node name.
        in_bounds = it.inc();
        var this_node: Node = .{
            .token_name_idx = it.idx,
            .node_children_start_idx = cast(u32, set.node_list.len + 1),
        };
        in_bounds = it.inc();

        // Go to `;` to process node.
        this_node.expr_start_idx = cast(u32, set.expr_list.len);
        node: while (in_bounds and it.getToken().token != .semicolon) {

            // Error case: floating `:`
            if (it.getToken().token == .colon) {
                return log.reportError(errorWriter, log.SyntaxError.NoExprName, set, it.getToken().idx);
            }

            // Error case: floating `=`
            if (it.getToken().token == .equals) {
                return log.reportError(errorWriter, log.SyntaxError.AssignmentToNothing, set, it.getToken().idx);
            }

            // Case: `name:maybe_type=expression`
            if (it.getToken().token == .unresolved) {
                in_bounds = try parseDeclaration(allocator, errorWriter, set);
                this_node.expr_end_idx = cast(u32, set.expr_list.len);
                continue :node;
            }

            // `{`: Recurse in body.
            if (it.getToken().token == .curly_left and it.nextToken().token != .curly_right) {
                in_bounds = it.inc();

                try set.node_list.append(allocator, this_node);
                appended_this = true;
                const this_node_idx = set.node_list.len - 1;
                var this_node_again = set.node_list.get(set.node_list.len - 1);
                try parseFromTokenList(allocator, errorWriter, set);
                this_node_again.node_children_end_idx = cast(u32, set.node_list.len);
                set.node_list.set(this_node_idx, this_node_again);

                // Error case: token after body end is not a semicolon.
                if (it.getToken().token != .semicolon) {
                    if (it.getToken().token == .at) return log.reportError(
                        errorWriter,
                        log.SyntaxError.NoSemicolonAfterNode,
                        set,
                        it.getToken().idx,
                    );

                    return log.reportError(errorWriter, log.SyntaxError.NoSemicolonAfterBody, set, it.getToken().idx);
                }
                // Node over.
                break :node;
            }
            // Ignore empty body.
            else if (it.getToken().token == .curly_left and it.nextToken().token == .curly_right) {
                in_bounds = it.inc();
            }

            // The semicolon required before a new node or body end would've ended this loop, so:
            // `}` shouldn't be here if previous node wasn't `{` (empty body);
            // `@` shouldn't be here.
            if ((it.getToken().token == .curly_right and it.prevToken().token != .curly_left) or
                it.getToken().token == .at)
            {
                return log.reportError(errorWriter, log.SyntaxError.NoSemicolonAfterNode, set, it.getToken().idx);
            }
            in_bounds = it.inc();
        } // :node

        // Node over, so continue the outer loop.
        if (!appended_this) try set.node_list.append(allocator, this_node);
        continue :root;
    } // :root

    // End of file and no semicolon.
    if (!in_bounds and it.nextToken().token != .semicolon) return log.reportError(
        errorWriter,
        log.SyntaxError.NoSemicolonAfterNode,
        set,
        it.getToken().lastByteIdx(set),
    );
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
    expr: while (in_bounds) : (in_bounds = it.inc()) {
        switch (it.getToken().token) {
            // Expression name: `name:...`
            .unresolved => {
                try parse.ensureNotKeyword(
                    errorWriter,
                    &parse.reserved_all,
                    log.SyntaxError.NameIsKeyword,
                    set,
                    it.getToken().idx,
                    it.getToken().idx,
                );
                var this_token = it.getToken();
                set.token_list.set(it.idx, .{
                    .token = .expr_name,
                    .idx = this_token.idx,
                });
                continue :expr;
            },
            // Type syntax: `name : type`
            .colon => {
                // Resolve type in '...:type=...'.
                in_bounds = it.inc();
                if (it.getToken().token == .unresolved) {
                    const type_string = it.getToken().lexeme(set);
                    this_expr.type = type_map.get(type_string) orelse {
                        // Error case: invalid type specifier.
                        return log.reportError(
                            errorWriter,
                            log.SyntaxError.InvalidTypeSpecifier,
                            set,
                            it.getToken().idx,
                        );
                    };
                    var this_token = it.getToken();
                    set.token_list.set(it.idx, .{
                        .token = this_expr.type,
                        .idx = this_token.idx,
                    });
                    continue :expr;
                }
                // Error case: inferred type uses `=`, not `:=`
                if (it.getToken().token == .equals) {
                    return log.reportError(errorWriter, log.SyntaxError.NoTypeAfterColon, set, it.getToken().idx);
                }
            },
            .equals => {
                in_bounds = it.inc();
                // Expression is `...=unresolved`, where `unresolved` is either
                // an expression name, a date, or a number.
                if (this_expr.type == .unresolved) this_expr.type = .type_infer;
                const this_token_type = it.getToken().token;
                switch (this_token_type) {
                    .unresolved, .str, .paren_left => {
                        if (this_token_type == .str) this_expr.type = .type_str;
                        in_bounds = try parseExpression(allocator, errorWriter, set, &this_expr);
                        break :expr;
                    },
                    else => {
                        // Error case: no valid expression after `=`
                        return log.reportError(errorWriter, log.SyntaxError.NoExpr, set, it.getToken().idx);
                    },
                }
            },
            else => {
                return log.reportError(errorWriter, log.SyntaxError.Unimplemented, set, it.getToken().idx);
            },
        } // switch (it.getToken().token)
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
        it.getToken().idx,
        it.getToken().idx,
    );

    expr.token_start_idx = it.idx;
    _ = it.inc();
    try set.expr_list.append(allocator, expr.*);
    return !it.atEnd();
}

pub const TokenIterator = struct {
    set: *parse.Set = undefined,
    idx: u32 = 0,
    const Self = @This();

    fn atEnd(self: *Self) bool {
        return (self.idx == self.set.token_list.len - 1);
    }

    fn getToken(self: *Self) token.Token {
        return self.set.token_list.get(self.idx);
    }

    fn inc(self: *Self) bool {
        if (self.idx == self.set.token_list.len - 1) return false;
        self.idx += 1;
        return true;
    }

    fn nextToken(self: *Self) token.Token {
        if (self.idx == self.set.token_list.len - 1) return self.getToken();
        return self.set.token_list.get(self.idx + 1);
    }

    fn prevToken(self: *Self) token.Token {
        if (self.idx == 0) return self.getToken();
        return self.set.token_list.get(self.idx - 1);
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
