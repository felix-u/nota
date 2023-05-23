const std = @import("std");
const ast = @import("ast.zig");
const token = @import("token.zig");

pub fn main() !void {
    // Allocator setup.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Error writers will print to stdout.
    const stdout = std.io.getStdOut().writer();

    // Args setup.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        try stdout.print("nota: expected file\n", .{});
        std.os.exit(1);
    }

    // Read file into buffer.
    const filepath = args[1];
    const infile = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer infile.close();
    const filebuf = try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(filebuf);

    var token_list = token.TokenList{};
    var token_pos: token.ParsePosition = .{ .buf = filebuf };
    try token.parseFromBuf(&token_pos, &token_list, allocator);

    // Print tokens (for now).
    try stdout.print("=== TOKENS: BEGIN ===\n", .{});
    for (0..token_list.len) |i| {
        const item = token_list.get(i);
        const position = item.filePosition(filebuf);
        try stdout.print("{d}:{d}\t\"{s}\"\t{}\n", .{
            position.line,
            position.col,
            item.lexeme(filebuf),
            item.token,
        });
    }
    try stdout.print("=== TOKENS: END ===\n", .{});

    var ast_set: ast.Set = .{};
    var ast_pos: ast.ParsePosition = .{ .buf = filebuf, .token_list = token_list };
    try ast.parseFromTokenList(&ast_pos, token_list, ast_set, allocator, stdout);

    // Print AST (for now).
    try stdout.print("=== AST: BEGIN ===\n", .{});

    try stdout.print("=== AST: END ===\n", .{});
}
