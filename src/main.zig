const std = @import("std");
const args = @import("args.zig");
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
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args_parsed = try args.parseAlloc(allocator, stdout, argv, .{
        .description = "general-purpose declarative notation",
        .version = "0.4-dev",
        .commands = &.{
            args.Command{
                // .name = "print",
                // .description = "parse nota file and print its structure",
                .kind = .single_positional_required,
                .flags = &.{
                    args.Flag{
                        .short_form = 'd',
                        .long_form = "debug",
                        .description = "Enable debugging-oriented formatting",
                    },
                },
            },
        },
    }) orelse return;
    defer allocator.destroy(args_parsed);

    if (argv.len == 1) {
        try stdout.print("nota: expected file\n", .{});
        std.os.exit(1);
    }

    // Read file into buffer.
    const filepath = argv[args_parsed.no_command.pos];
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
    var token_pos: token.ParsePosition = .{ .filepath = absolute_filepath, .buf = filebuf };
    try token.parseFromBuf(&token_pos, &token_list, allocator, stdout, false);

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
    var ast_set: ast.Set = .{
        .filepath = absolute_filepath,
        .buf = filebuf,
        .token_list = token_list,
    };
    var ast_pos: ast.ParsePosition = .{ .set = ast_set };
    const node_list_len = try ast.parseFromTokenList(&ast_pos, &ast_set, allocator, stdout);

    // try stdout.print("=== TOKENS 2: BEGIN ===\n", .{});
    // for (0..token_list.len) |i| {
    //     const item = token_list.get(i);
    //     var position: log.filePosition = .{
    //         .filepath = absolute_filepath,
    //         .buf = filebuf,
    //         .idx = item.idx,
    //     };
    //     position.computeCoords();
    //     try stdout.print("{d}:{d}\t{d}\t\"{s}\"\t{}\n", .{
    //         position.line,
    //         position.col,
    //         i,
    //         item.lexeme(filebuf),
    //         item.token,
    //     });
    // }
    // try stdout.print("=== TOKENS 2: END ===\n", .{});

    // try stdout.print("{} nodes\n", .{ast_set.node_list.len});
    // for (0..ast_set.node_list.len) |i| {
    //     try stdout.print("{}\n", .{ast_set.node_list.get(i)});
    // }
    // try stdout.print("{} expressions\n", .{ast_set.expr_list.len});
    // for (0..ast_set.expr_list.len) |i| {
    //     try stdout.print("{}\n", .{ast_set.expr_list.get(i)});
    // }
    // try stdout.print("=== AST: END ===\n", .{});

    try ast.printDebugView(&ast_set, 0, 0, node_list_len, stdout);
}
