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

        var parse_set = parse.Set{
            .filepath = filepath,
            .buf = filebuf,
            .buf_it = (try std.unicode.Utf8View.init(filebuf)).iterator(),
        };

        token.fromBufAlloc(allocator, stderr, &parse_set) catch std.os.exit(1);
        ast.fromToksAlloc(allocator, stderr, &parse_set) catch std.os.exit(1);

        std.os.exit(0);
    }

    if (args_parsed.print.invoked) {
        const filepath = args_parsed.print.pos;
        const filebuf = try readFileAlloc(allocator, filepath);
        defer allocator.free(filebuf);
        const debug_view = args_parsed.print.debug;

        var parse_set = parse.Set{
            .filepath = filepath,
            .buf = filebuf,
            .buf_it = (try std.unicode.Utf8View.init(filebuf)).iterator(),
        };

        if (debug_view) try stdout.print("=== TOK: BEG ===\n", .{});

        try token.fromBufAlloc(allocator, stderr, &parse_set);

        if (debug_view) {
            for (0..parse_set.toks.len) |i| {
                const tok = parse_set.toks.get(i);
                var pos: log.filePos = .{ .set = &parse_set, .i = tok.beg_i };
                pos.computeCoords();
                try stdout.print(
                    "{d}:{d}\t{d}\t\"{s}\"\t{}\n",
                    .{ pos.row, pos.col, i, parse_set.buf[tok.beg_i..tok.end_i], tok.kind },
                );
            }
            try stdout.print("=== TOK: END ===\n", .{});
            try stdout.print("\n=== AST: BEG ===\n", .{});
        }

        try parse_set.nodes.append(allocator, .{ .childs_beg_i = 0 });
        try ast.fromToksAlloc(allocator, stderr, &parse_set);
        parse_set.nodes.items(.childs_end_i)[0] = @intCast(parse_set.nodes.len);

        if (debug_view) {
            // for (0..parse_set.nodes.len) |i| {
            //     const node = parse_set.nodes.get(i);
            //     try stdout.print("{any}\n", .{node});
            // }
            var node_i: u32 = 0;
            try ast.printDebug(stdout, &parse_set, 0, &node_i);

            try stdout.print("=== AST: END ===\n", .{});
        }

        std.os.exit(0);
    }
}

fn readFileAlloc(allocator: std.mem.Allocator, filepath: []const u8) ![]const u8 {
    const cwd = std.fs.cwd();

    const infile = try cwd.openFile(filepath, .{ .mode = .read_only });
    defer infile.close();

    return try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
}
