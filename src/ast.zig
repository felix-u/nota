const std = @import("std");
const cast = std.math.lossyCast;
const log = @import("log.zig");
const resolver = @import("resolver.zig");
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

const Expr = struct {
    type: token.Kind = .unresolved,
    token_name_idx: u32 = 0,
    token_start_idx: u32 = 0,
};
const ExprList = std.MultiArrayList(Expr);

pub const Set = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    token_list: token.TokenList = token.TokenList{},
    node_list: NodeList = NodeList{},
    expr_list: ExprList = ExprList{},
};

pub fn parseFromTokenList(
    pos: *ParsePosition,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !u32 {
    var in_bounds = !pos.atEnd();
    var appended_this = false;

    root: while (in_bounds) : (in_bounds = pos.inc()) {
        // First token in loop is guaranteed to be either `@` or `}`.
        if (pos.getToken().token == .curly_right) {
            in_bounds = pos.inc();
            break;
        }

        // Error case: name doesn't immediately follow `@`.
        if (pos.nextToken().token != .node_name) {
            var err_loc: log.filePosition = .{
                .filepath = set.filepath,
                .buf = set.buf,
                .idx = pos.getToken().idx,
            };
            err_loc.computeCoords();
            return log.reportError(log.SyntaxError.NoNodeName, err_loc, errorWriter);
        }

        // Get node name.
        in_bounds = pos.inc();
        var this_node: Node = .{
            .token_name_idx = pos.idx,
            .node_children_start_idx = cast(u32, set.node_list.len + 1),
        };
        in_bounds = pos.inc();

        // Go to `;` to process node.
        this_node.expr_start_idx = cast(u32, set.expr_list.len);
        node: while (in_bounds and pos.getToken().token != .semicolon) {

            // Error case: floating `:`
            if (pos.getToken().token == .colon) {
                var err_loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.NoExprName, err_loc, errorWriter);
            }

            // Error case: floating `=`
            if (pos.getToken().token == .equals) {
                var err_loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.AssignmentToNothing, err_loc, errorWriter);
            }

            // Case: `name:maybe_type=expression`
            if (pos.getToken().token == .unresolved) {
                in_bounds = try parseDeclaration(pos, set, allocator, errorWriter);
                this_node.expr_end_idx = cast(u32, set.expr_list.len);
                continue :node;
            }

            // `{`: Recurse in body.
            if (pos.getToken().token == .curly_left and pos.nextToken().token != .curly_right) {
                in_bounds = pos.inc();

                try set.node_list.append(allocator, this_node);
                appended_this = true;
                const this_node_idx = set.node_list.len - 1;
                var this_node_again = set.node_list.get(set.node_list.len - 1);
                this_node_again.node_children_end_idx = try parseFromTokenList(pos, set, allocator, errorWriter);
                set.node_list.set(this_node_idx, this_node_again);

                // Error case: token after body end is not a semicolon.
                if (pos.getToken().token != .semicolon) {
                    var err_loc: log.filePosition = .{
                        .filepath = set.filepath,
                        .buf = set.buf,
                        .idx = pos.getToken().idx,
                    };
                    err_loc.computeCoords();
                    if (pos.getToken().token == .at) {
                        return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
                    }
                    return log.reportError(log.SyntaxError.NoSemicolonAfterBody, err_loc, errorWriter);
                }
                // Node over.
                break :node;
            }
            // Ignore empty body.
            else if (pos.getToken().token == .curly_left and pos.nextToken().token == .curly_right) {
                in_bounds = pos.inc();
            }

            // The semicolon required before a new node or body end would've ended this loop, so:
            // `}` shouldn't be here if previous node wasn't `{` (empty body);
            // `@` shouldn't be here.
            if ((pos.getToken().token == .curly_right and pos.prevToken().token != .curly_left) or pos.getToken().token == .at) {
                var err_loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
            }
            in_bounds = pos.inc();
        } // :node

        // Node over, so continue the outer loop.
        if (!appended_this) try set.node_list.append(allocator, this_node);
        continue :root;
    } // :root

    // End of file and no semicolon.
    if (!in_bounds and pos.nextToken().token != .semicolon) {
        var err_loc: log.filePosition = .{
            .filepath = set.filepath,
            .buf = set.buf,
            .idx = pos.getToken().lastByteIdx(set.buf),
        };
        err_loc.computeCoords();
        return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
    }

    return cast(u32, set.node_list.len);
}

fn parseDeclaration(
    pos: *ParsePosition,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !bool {
    var this_expr: Expr = .{
        .type = .unresolved,
        .token_name_idx = pos.idx,
    };

    var in_bounds = !pos.atEnd();
    expr: while (in_bounds) : (in_bounds = pos.inc()) {
        switch (pos.getToken().token) {
            // Expression name: `name:...`
            .unresolved => {
                var loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                try resolver.ensureNotKeyword(
                    &resolver.reserved_all,
                    log.SyntaxError.NameIsKeyword,
                    pos.getToken().lexeme(set.buf),
                    &loc,
                    errorWriter,
                );
                var this_token = pos.getToken();
                set.token_list.set(pos.idx, .{
                    .token = .expr_name,
                    .idx = this_token.idx,
                });
                continue :expr;
            },
            // Type syntax: `name : type`
            .colon => {
                // Resolve type in '...:type=...'.
                in_bounds = pos.inc();
                if (pos.getToken().token == .unresolved) {
                    const type_string = pos.getToken().lexeme(set.buf);
                    this_expr.type = type_map.get(type_string) orelse {
                        // Error case: invalid type specifier.
                        var err_loc: log.filePosition = .{
                            .filepath = set.filepath,
                            .buf = set.buf,
                            .idx = pos.getToken().idx,
                        };
                        err_loc.computeCoords();
                        return log.reportError(log.SyntaxError.InvalidTypeSpecifier, err_loc, errorWriter);
                    };
                    var this_token = pos.getToken();
                    set.token_list.set(pos.idx, .{
                        .token = this_expr.type,
                        .idx = this_token.idx,
                    });
                    continue :expr;
                }
                // Error case: inferred type uses `=`, not `:=`
                if (pos.getToken().token == .equals) {
                    var err_loc: log.filePosition = .{
                        .filepath = set.filepath,
                        .buf = set.buf,
                        .idx = pos.getToken().idx,
                    };
                    err_loc.computeCoords();
                    return log.reportError(log.SyntaxError.NoTypeAfterColon, err_loc, errorWriter);
                }
            },
            .equals => {
                in_bounds = pos.inc();
                // Expression is `...=unresolved`, where `unresolved` is either
                // an expression name, a date, or a number.
                if (this_expr.type == .unresolved) this_expr.type = .type_infer;
                const this_token_type = pos.getToken().token;
                if (this_token_type == .unresolved or this_token_type == .str) {
                    if (this_token_type == .str) this_expr.type = .type_str;
                    in_bounds = try parseExpression(pos, set, &this_expr, allocator, errorWriter);
                    break :expr;
                }
                // Error case: no valid expression after `=`
                var err_loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.NoExpr, err_loc, errorWriter);
            },
            else => {
                var err_loc: log.filePosition = .{
                    .filepath = set.filepath,
                    .buf = set.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.Unimplemented, err_loc, errorWriter);
            },
        } // switch (pos.getToken().token)
    } // :expr

    return in_bounds;
}

fn parseExpression(
    pos: *ParsePosition,
    set: *Set,
    expr: *Expr,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !bool {
    var loc: log.filePosition = .{
        .filepath = set.filepath,
        .buf = set.buf,
        .idx = pos.getToken().idx,
    };
    try resolver.ensureNotKeyword(
        &resolver.reserved_types,
        log.SyntaxError.ExprIsTypeName,
        pos.getToken().lexeme(set.buf),
        &loc,
        errorWriter,
    );

    expr.token_start_idx = pos.idx;
    _ = pos.inc();
    try set.expr_list.append(allocator, expr.*);
    return !pos.atEnd();
}

pub const ParsePosition = struct {
    set: Set = .{},
    idx: u32 = 0,
    fn atEnd(self: *ParsePosition) bool {
        return (self.idx == self.set.token_list.len - 1);
    }
    fn getToken(self: *ParsePosition) token.Token {
        return self.set.token_list.get(self.idx);
    }
    fn inc(self: *ParsePosition) bool {
        if (self.idx == self.set.token_list.len - 1) return false;
        self.idx += 1;
        return true;
    }
    fn nextToken(self: *ParsePosition) token.Token {
        if (self.idx == self.set.token_list.len - 1) return self.getToken();
        return self.set.token_list.get(self.idx + 1);
    }
    fn prevToken(self: *ParsePosition) token.Token {
        if (self.idx == 0) return self.getToken();
        return self.set.token_list.get(self.idx - 1);
    }
};

pub fn printDebugView(
    set: *Set,
    level: usize,
    node_list_start: u32,
    node_list_end: u32,
    writer: std.fs.File.Writer,
) !void {
    var node_list_idx = node_list_start;
    while (node_list_idx < node_list_end) : (node_list_idx += 1) {
        const node = set.node_list.get(node_list_idx);
        const node_name = set.token_list.get(node.token_name_idx).lexeme(set.buf);

        for (level) |_| try writer.print("\t", .{});
        try writer.print("{s} <<<\n", .{node_name});

        for (level) |_| try writer.print("\t", .{});
        try writer.print("{}\n", .{node});

        for (level) |_| try writer.print("\t", .{});
        try writer.print("EXPR <\n", .{});
        var expr_idx = node.expr_start_idx;
        while (expr_idx < node.expr_end_idx) : (expr_idx += 1) {
            const expr = set.expr_list.get(expr_idx);

            for (level) |_| try writer.print("\t", .{});
            try writer.print("{s} = ", .{set.token_list.get(expr.token_name_idx).lexeme(set.buf)});

            for (level) |_| try writer.print("\t", .{});
            try writer.print("{}\n", .{expr});
        }
        for (level) |_| try writer.print("\t", .{});
        try writer.print(">\n", .{});

        try printDebugView(set, level + 1, node.node_children_start_idx, node.node_children_end_idx, writer);
        if (node.node_children_end_idx > node.node_children_start_idx) {
            node_list_idx = node.node_children_end_idx - 1;
        }

        for (level) |_| try writer.print("\t", .{});
        try writer.print(">>> {s}\n", .{node_name});
    }
}
