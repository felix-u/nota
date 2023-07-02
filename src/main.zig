const std = @import("std");
const args = @import("args.zig");
const ast = @import("ast.zig");
const log = @import("log.zig");
const parse = @import("parse.zig");
const token = @import("token.zig");

pub fn main() !void {
    // Allocator setup.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    // Args setup.
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args_parsed = args.parseAlloc(allocator, stdout, argv, .{
        .description = "general-purpose declarative notation",
        .version = "0.4-dev",
        .commands = &.{
            args.Command{
                // .name = "print",
                // .description = "parse nota file and print its structure",
                .kind = .required_single_positional,
                .flags = &.{
                    args.Flag{
                        .short_form = 'd',
                        .long_form = "debug",
                        .description = "Enable debugging-oriented formatting",
                    },
                },
            },
        },
    }) catch {
        std.os.exit(1);
    } orelse return;
    defer allocator.destroy(args_parsed);

    // Read file into buffer.
    const filepath = argv[args_parsed.no_command.pos];
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

    // Tokeniser.
    try stdout.print("=== TOKENS: BEGIN ===\n", .{});
    token.parseFromBufAlloc(allocator, stdout, &parse_set, false) catch std.os.exit(1);

    // Print tokens (for now).
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

    // AST.
    try stdout.print("=== AST: BEGIN ===\n", .{});
    ast.parseFromTokenList(allocator, stdout, &parse_set) catch std.os.exit(1);

    try ast.printDebugView(stdout, &parse_set, 0, 0, std.math.lossyCast(u32, parse_set.node_list.len));
}
