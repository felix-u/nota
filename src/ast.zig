const std = @import("std");
const log = @import("log.zig");
const token = @import("token.zig");

pub const Node = struct {
    parent_idx: u32 = 0,
    name_idx: u32 = 0,
    expr_list_idx: u32 = 0,
    children_idx: u32 = 0,
};

pub const NodeList = std.MultiArrayList(Node);

const type_map = std.ComptimeStringMap(token.TokenType, .{
    .{ "bool", token.TokenType.type_bool },
    .{ "date", token.TokenType.type_date },
    .{ "num", token.TokenType.type_num },
    .{ "str", token.TokenType.type_str },
});

const Expr = struct {
    type: token.TokenType = .unresolved,
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
) !void {
    var in_bounds = !pos.atEnd();

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
        var this_node: Node = .{ .name_idx = pos.idx };
        in_bounds = pos.inc();

        // Go to `;` to process node.
        this_node.expr_list_idx = pos.idx;
        node: while (in_bounds and pos.getToken().token != .semicolon) : (in_bounds = pos.inc()) {

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
                continue :node;
            }

            // `{`: Recurse in body.
            if (pos.getToken().token == .curly_left and pos.nextToken().token != .curly_right) {
                in_bounds = pos.inc();
                try parseFromTokenList(pos, set, allocator, errorWriter);
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
                // Node over (node has body), so we'll continue the outer loop.
                try set.node_list.append(allocator, this_node);
                continue :root;
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
        }

        // Node over (node has no body), so we'll continue the outer loop.
        try set.node_list.append(allocator, this_node);
    } // :node

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
}

fn parseDeclaration(
    pos: *ParsePosition,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !bool {
    const expr_start_idx = pos.idx;
    var expr_type: token.TokenType = .unresolved;

    var in_bounds = !pos.atEnd();
    expr: while (in_bounds) : (in_bounds = pos.inc()) {
        switch (pos.getToken().token) {
            // Expression name: `name:...`
            .unresolved => {
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
                    expr_type = type_map.get(type_string) orelse .unresolved;
                    // Error case: invalid type specifier.
                    if (expr_type == .unresolved) {
                        var err_loc: log.filePosition = .{
                            .filepath = set.filepath,
                            .buf = set.buf,
                            .idx = pos.getToken().idx,
                        };
                        err_loc.computeCoords();
                        return log.reportError(log.SyntaxError.InvalidTypeSpecifier, err_loc, errorWriter);
                    }
                    var this_token = pos.getToken();
                    set.token_list.set(pos.idx, .{
                        .token = expr_type,
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
                // Expression is `...=unresolved`, where `unresolved` is either
                // an expression name, a date, or a number.
                if (pos.nextToken().token == .unresolved) {
                    in_bounds = pos.inc();
                    in_bounds = try parseExpression(pos, set, allocator, errorWriter);
                    break :expr;
                }
                if (pos.nextToken().token == .str) {
                    in_bounds = pos.inc();
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

    try set.expr_list.append(allocator, .{
        .type = expr_type,
        .token_start_idx = expr_start_idx,
    });

    return in_bounds;
}

fn parseExpression(
    pos: *ParsePosition,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !bool {
    _ = set;
    _ = allocator;
    _ = errorWriter;
    // Placeholder.
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
