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
    const stderr = std.io.getStdErr().writer();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args_parsed = args.parseAlloc(allocator, stdout, stderr, argv, .{
        .desc = "general-purpose declarative notation language",
        .ver = "0.4-dev",
        .usage = "<command> <file> [options]",
        .cmds = &.{
            args.Cmd{
                .name = "print",
                .desc = "parse nota file and print its structure",
                .usage = "<file> [options]",
                .kind = .single_pos,
                .flags = &.{
                    args.Flag{
                        .short = 'd',
                        .long = "debug",
                        .desc = "Enable debugging-oriented formatting",
                    },
                },
            },
            args.Cmd{
                .name = "check",
                .desc = "check nota file for syntax errors",
                .usage = "<file>",
                .kind = .single_pos,
            },
        },
    }) catch {
        std.os.exit(1);
    } orelse return;
    defer allocator.destroy(args_parsed);

    if (args_parsed.check.invoked) {
        const filepath = args_parsed.check.pos;
        const filebuf = try readFileAlloc(allocator, filepath);
        defer allocator.free(filebuf);

        const set = try parse.Set.init(allocator, filepath, filebuf);

        token.parseBuf(stderr, set) catch std.os.exit(1);
        ast.parseToks(stderr, set, false) catch std.os.exit(1);

        std.os.exit(0);
    }

    if (args_parsed.print.invoked) {
        const filepath = args_parsed.print.pos;
        const filebuf = try readFileAlloc(allocator, filepath);
        defer allocator.free(filebuf);
        const debug_view = args_parsed.print.debug;

        const set = try parse.Set.init(allocator, filepath, filebuf);

        if (debug_view) try stdout.print("=== TOK: BEG ===\n", .{});

        try token.parseBuf(stderr, set);

        if (debug_view) {
            for (0..set.toks.len) |i| {
                const tok = set.toks.get(i);
                var pos: log.filePos = .{ .set = set, .i = tok.beg_i };
                pos.computeCoords();
                try stdout.print(
                    "{d}:{d}\t{d}\t\"{s}\"\t{}\n",
                    .{ pos.row, pos.col, i, tok.lexeme(set), tok.kind },
                );
            }
            try stdout.print("=== TOK: END ===\n", .{});
            try stdout.print("\n=== AST: BEG ===\n", .{});
        }

        try set.nodes.append(allocator, .{});
        try ast.parseToks(stderr, set, false);

        if (debug_view) {
            var node_i: u32 = 0;
            try ast.printDebug(stdout, set, &node_i);

            try stdout.print("=== AST: END ===\n", .{});
        }

        std.os.exit(0);
    }
}

fn readFileAlloc(
    allocator: std.mem.Allocator,
    filepath: []const u8,
) ![]const u8 {
    const cwd = std.fs.cwd();

    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();

    return try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
}
