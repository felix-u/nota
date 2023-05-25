const std = @import("std");
const log = @import("log.zig");
const token = @import("./token.zig");

pub const Node = struct {
    name_idx: u32 = 0,
    expr_list: struct {
        start_idx: u32 = 0,
        end_idx: u32 = 0,
    } = .{},
    parent: u32 = undefined,
    children: struct {
        start_idx: u32 = undefined,
        end_idx: u32 = undefined,
    } = .{},
};

pub const NodeList = std.MultiArrayList(Node);

const Expr = struct {
    type: enum(u8) { unresolved, str, num, date } = .unresolved,
    evaluated: bool = false,
    token_list: struct {
        start_idx: u32 = 0,
        end_idx: u32 = 0,
    } = .{},
};

const ExprList = std.MultiArrayList(Expr);

pub const Set = struct {
    token_list: token.TokenList = token.TokenList{},
    node_list: NodeList = NodeList{},
    expr_list: ExprList = ExprList{},
};

pub fn parseFromTokenList(
    pos: *ParsePosition,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
    // comptime in_body: bool,
) !void {
    var in_bounds = !pos.atEnd();

    node: while (in_bounds) : (in_bounds = pos.inc()) {
        // First token in loop is guaranteed to be either `@` or `}`.
        if (pos.getToken().token == .curly_right) {
            in_bounds = pos.inc();
            break;
        }

        // Error case: name doesn't immediately follow `@`.
        if (pos.nextToken().token != .name) {
            var err_loc: log.filePosition = .{
                .filepath = pos.filepath,
                .buf = pos.buf,
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
        this_node.expr_list.start_idx = pos.idx;
        while (in_bounds and pos.getToken().token != .semicolon) : (in_bounds = pos.inc()) {
            // `{`: Recurse in body.
            if (pos.getToken().token == .curly_left and pos.nextToken().token != .curly_right) {
                // while (in_bounds and pos.getToken().token != .curly_right) : (in_bounds = pos.inc()) {}
                in_bounds = pos.inc();
                try parseFromTokenList(pos, set, allocator, errorWriter);
                if (pos.getToken().token != .semicolon) {
                    var err_loc: log.filePosition = .{
                        .filepath = pos.filepath,
                        .buf = pos.buf,
                        .idx = pos.getToken().idx,
                    };
                    err_loc.computeCoords();
                    if (pos.getToken().token == .at) {
                        return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
                    }
                    return log.reportError(log.SyntaxError.NoSemicolonAfterBody, err_loc, errorWriter);
                }
                // Node over (node has body), so we'll continue the outer loop.
                this_node.expr_list.end_idx = pos.idx;
                try set.node_list.append(allocator, this_node);
                continue :node;
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
                    .filepath = pos.filepath,
                    .buf = pos.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
            }
        }

        // Node over (node has no body), so we'll continue the outer loop.
        this_node.expr_list.end_idx = pos.idx;
        try set.node_list.append(allocator, this_node);
    } // :node

    // End of file and no semicolon.
    if (!in_bounds and pos.nextToken().token != .semicolon) {
        var err_loc: log.filePosition = .{
            .filepath = pos.filepath,
            .buf = pos.buf,
            .idx = pos.getToken().lastByteIdx(pos.buf),
        };
        err_loc.computeCoords();
        return log.reportError(log.SyntaxError.NoSemicolonAfterNode, err_loc, errorWriter);
    }
}

pub const ParsePosition = struct {
    filepath: []const u8 = undefined,
    buf: []const u8 = undefined,
    token_list: token.TokenList = undefined,
    idx: u32 = 0,
    fn atEnd(self: *ParsePosition) bool {
        return (self.idx == self.token_list.len - 1);
    }
    fn getToken(self: *ParsePosition) token.Token {
        return self.token_list.get(self.idx);
    }
    fn inc(self: *ParsePosition) bool {
        if (self.idx == self.token_list.len - 1) return false;
        self.idx += 1;
        return true;
    }
    fn nextToken(self: *ParsePosition) token.Token {
        if (self.idx == self.token_list.len - 1) return self.getToken();
        return self.token_list.get(self.idx + 1);
    }
    fn prevToken(self: *ParsePosition) token.Token {
        if (self.idx == 0) return self.getToken();
        return self.token_list.get(self.idx - 1);
    }
};
