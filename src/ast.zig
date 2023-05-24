const std = @import("std");
const log = @import("log.zig");
const token = @import("./token.zig");

pub const Node = struct {
    name_idx: u32,
    expr_list: struct {
        start_idx: u32,
        end_idx: u32,
    },
};

pub const NodeList = std.MultiArrayList(Node);

const Expr = struct {
    type: enum(u8) { unresolved, str, num, date } = .unresolved,
    evaluated: bool,
    token_list: struct {
        start_idx: u32,
        end_idx: u32,
    },
};

const ExprList = std.MultiArrayList(Expr);

pub const Set = struct {
    node_list: NodeList = NodeList{},
    expr_list: ExprList = ExprList{},
};

pub fn parseFromTokenList(
    pos: *ParsePosition,
    token_list: token.TokenList,
    set: *Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !void {
    const tokens = token_list.items(.token);

    // The tokeniser guarantees that the first token is `@`.
    // We can continue till we find ';' (correct usage), or '@' or EOF (syntax error).

    var in_bounds = pos.inc();
    root: while (in_bounds) : (in_bounds = pos.inc()) {
        // No name after `@`.
        if (tokens[pos.idx] != .name) {
            std.debug.print("{}\n", .{pos.getToken()});
            var at_loc: log.filePosition = .{
                .filepath = pos.filepath,
                .buf = pos.buf,
                .idx = pos.prevToken().idx,
            };
            at_loc.computeCoords();
            return log.reportError(log.SyntaxError.NoNodeName, at_loc, errorWriter);
        }

        // Get node expressions.
        node: while (in_bounds) : (in_bounds = pos.inc()) {
            const start_idx = pos.idx;

            // TODO: Will parse expressions here.
            while (in_bounds and tokens[pos.idx] != .at) : (in_bounds = pos.inc()) {
                // TODO: Recursion needs to happen here to process children.
                if (tokens[pos.idx] == .curly_left) {
                    // while (in_bounds and tokens[pos.idx] != .curly_right) : (in_bounds = pos.inc()) {}
                    if (pos.nextToken().token != .curly_right) {
                        in_bounds = pos.inc();
                        try parseFromTokenList(pos, token_list, set, allocator, errorWriter);
                    }
                    if (pos.atEnd()) break :root;
                    const prev_token = pos.prevToken();
                    // Error case: missing semicolon.
                    if (prev_token.token != .semicolon and prev_token.token != .curly_left) {
                        std.debug.print("{}\t{}\n", .{ prev_token.token, pos.getToken().token });
                        var err_loc: log.filePosition = .{
                            .filepath = pos.filepath,
                            .buf = pos.buf,
                            .idx = pos.getToken().idx,
                        };
                        err_loc.computeCoords();
                        return log.reportError(log.SyntaxError.MissingSemicolon, err_loc, errorWriter);
                    }
                }
            }
            std.debug.print("{}\t{}\n", .{ pos.prevToken(), pos.getToken() });
            if (!in_bounds) break :root;

            const prev_token = pos.prevToken();
            if (prev_token.token != .semicolon) {
                var err_loc: log.filePosition = .{
                    .filepath = pos.filepath,
                    .buf = pos.buf,
                    .idx = pos.getToken().idx,
                };
                err_loc.computeCoords();
                return log.reportError(log.SyntaxError.MisplacedNode, err_loc, errorWriter);
            }
            if (!in_bounds) break :node;

            try set.node_list.append(allocator, .{
                .name_idx = start_idx,
                .expr_list = .{
                    .start_idx = 0,
                    .end_idx = 0,
                },
            });
            continue :root;
        } // :node
    } // :root
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
