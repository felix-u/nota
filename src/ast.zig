const token = @import("./token.zig");

pub const AstNode = struct {
    name: []const u8 = undefined,
};

const AstExpr = struct {
    type: enum { unresolved, str, num, date } = .unresolved,
    tokens: token.TokenList.Slice,
};
