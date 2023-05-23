const std = @import("std");
const token = @import("./token.zig");

pub const Set = struct {
    node_list: NodeList = NodeList{},
    expr_list: ExprList = ExprList{},
};

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

pub fn parseFromTokenList(
    pos: *ParsePosition,
    token_list: token.TokenList,
    set: Set,
    allocator: std.mem.Allocator,
    errorWriter: std.fs.File.Writer,
) !void {
    _ = allocator;
    const tokens = token_list.items(.token);

    // The tokeniser guarantees that the first token is `@`.
    // We can continue till we find ';' (correct usage), or '@' or EOF (syntax error).

    var in_bounds = pos.inc();
    while (in_bounds) : (in_bounds = pos.inc()) {
        if (tokens[pos.idx] != .name) {
            try errorWriter.print("{d}:{d}: error: expected \n", .{ pos.getToken().lexeme(pos.buf), tokens[pos.idx] });
        }
    }
    try errorWriter.print("{d}\n{d}\n", .{ set.node_list.len, set.expr_list.len });
}

pub const ParsePosition = struct {
    buf: []const u8 = undefined,
    token_list: token.TokenList = undefined,
    idx: u32 = 0,
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
