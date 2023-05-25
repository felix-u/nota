const std = @import("std");
const ast = @import("ast.zig");
const log = @import("log.zig");
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
    const cwd = std.fs.cwd();
    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();
    const filebuf = try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(filebuf);
    const absolute_filepath = try cwd.realpathAlloc(allocator, filepath);
    defer allocator.free(absolute_filepath);

    // Tokeniser.

    try stdout.print("=== TOKENS: BEGIN ===\n", .{});
    var token_list = token.TokenList{};
    var token_pos: token.ParsePosition = .{ .buf = filebuf };
    try token.parseFromBuf(&token_pos, &token_list, allocator, false);

    // Print tokens (for now).
    for (0..token_list.len) |i| {
        const item = token_list.get(i);
        var position: log.filePosition = .{
            .filepath = absolute_filepath,
            .buf = filebuf,
            .idx = item.idx,
        };
        position.computeCoords();
        try stdout.print("{d}:{d}\t{d}\t\"{s}\"\t{}\n", .{
            position.line,
            position.col,
            i,
            item.lexeme(filebuf),
            item.token,
        });
    }
    try stdout.print("=== TOKENS: END ===\n", .{});

    // AST.

    try stdout.print("=== AST: BEGIN ===\n", .{});
    var ast_set: ast.Set = .{ .token_list = token_list };
    var ast_pos: ast.ParsePosition = .{
        .filepath = absolute_filepath,
        .buf = filebuf,
        .token_list = ast_set.token_list,
    };
    try ast.parseFromTokenList(&ast_pos, &ast_set, allocator, stdout);

    // Print AST (for now).
    for (0..ast_set.node_list.len) |i| {
        const node = ast_set.node_list.get(i);
        const node_name = ast_set.token_list.get(node.name_idx).lexeme(ast_pos.buf);
        var node_position: log.filePosition = .{
            .buf = ast_pos.buf,
            .idx = ast_set.token_list.get(node.name_idx).idx,
        };
        node_position.computeCoords();
        try stdout.print("{d}:{d}\t{s}\t{}\n", .{ node_position.line, node_position.col, node_name, node });
    }

    try stdout.print("=== AST: END ===\n", .{});
}
