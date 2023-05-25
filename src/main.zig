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
    try ast.parseFromTokenList(&ast_pos, &ast_set, allocator, stdout, false);

    // Print AST (for now).
    for (0..ast_set.node_list.len) |i| {
        const node = ast_set.node_list.get(i);
        const node_token = token_list.get(node.name_idx);
        const node_name = node_token.lexeme(filebuf);
        var node_loc: log.filePosition = .{
            .buf = filebuf,
            .idx = node_token.idx,
        };
        node_loc.computeCoords();
        try stdout.print("{d}:{d}\tBEGIN {s}\n", .{
            node_loc.line,
            node_loc.col,
            node_name,
        });
        for (node.expr_list.start_idx..node.expr_list.end_idx + 1) |j| {
            const item = token_list.get(j);
            var position: log.filePosition = .{
                .filepath = absolute_filepath,
                .buf = filebuf,
                .idx = item.idx,
            };
            position.computeCoords();
            try stdout.print("{d}:{d}\t\"{s}\"\t{}\n", .{
                position.line,
                position.col,
                item.lexeme(filebuf),
                item.token,
            });
        }
        try stdout.print("\tEND {s}\n", .{node_name});
    }

    try stdout.print("=== AST: END ===\n", .{});
}
