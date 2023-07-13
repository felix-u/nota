const args = @import("args.zig");
const ast = @import("ast.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args_parsed = args.parseAlloc(allocator, stdout, argv, .{
        .desc = "general-purpose declarative notation",
        .ver = "0.4-dev",
        .cmds = &.{
            args.Cmd{
                // .name = "print",
                // .desc = "parse nota file and print its structure",
                .kind = .single_pos,
                .flags = &.{
                    args.Flag{
                        .short = 'd',
                        .long = "debug",
                        .desc = "Enable debugging-oriented formatting",
                    },
                },
            },
            // args.Cmd{
            //     .name = "check",
            //     .desc = "check nota file for syntax errors",
            //     .kind = .single_pos,
            // },
        },
    }) catch {
        std.os.exit(1);
    } orelse return;
    defer allocator.destroy(args_parsed);

    // // TODO
    // if (args_parsed.print == null) return;
    const cmd_print = args_parsed.no_command;

    const debug_view = cmd_print.debug;

    const filepath = argv[cmd_print.pos];
    const cwd = std.fs.cwd();
    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();
    const filebuf = try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(filebuf);
    const absolute_filepath = try cwd.realpathAlloc(allocator, filepath);
    defer allocator.free(absolute_filepath);

    var parse_set = parse.Set{
        .filepath = absolute_filepath,
        .buf = filebuf,
    };

    if (debug_view) try stdout.print("=== TOKENS: BEGIN ===\n", .{});

    try token.parseFromBufAlloc(allocator, stdout, &parse_set, false);

    if (debug_view) {
        for (0..parse_set.token_list.len) |i| {
            const item = parse_set.token_list.get(i);
            var position: log.filePosition = .{ .set = &parse_set, .idx = item.idx };
            position.computeCoords();
            try stdout.print("{d}:{d}\t{d}\t\"{s}\"\t{}\n", .{
                position.line,
                position.col,
                i,
                item.lexeme(&parse_set),
                item.token,
            });
        }
        try stdout.print("=== TOKENS: END ===\n", .{});

        try stdout.print("=== AST: BEGIN ===\n", .{});
    }

    try ast.parseFromTokenList(allocator, stdout, &parse_set, false);

    if (debug_view) {
        try ast.printDebugView(stdout, &parse_set, 0, 0, std.math.lossyCast(u32, parse_set.node_list.len));
        try stdout.print("=== AST: END ===\n", .{});
    } else {
        try ast.printNicely(stdout, &parse_set, 0, 0, std.math.lossyCast(u32, parse_set.node_list.len));
    }
}
