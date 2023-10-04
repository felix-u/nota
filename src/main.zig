const ansi = @import("ansi.zig");
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
                    args.Flag{
                        .long = "noclr",
                        .desc = "Disable ANSI colour in output",
                    },
                    args.Flag{
                        .long = "clr",
                        .desc = "Force ANSI colour in output",
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

        token.parseToksFromBuf(stderr, set) catch std.os.exit(1);
        ast.parseTreeFromToks(stderr, set) catch std.os.exit(1);

        std.os.exit(0);
    }

    if (args_parsed.print.invoked) {
        const filepath = args_parsed.print.pos;
        const filebuf = try readFileAlloc(allocator, filepath);
        defer allocator.free(filebuf);
        const debug_view = args_parsed.print.debug;

        const set = try parse.Set.init(allocator, filepath, filebuf);

        if (debug_view) try stdout.print("=== TOK: BEG ===\n", .{});

        try token.parseToksFromBuf(stderr, set);

        if (debug_view) {
            for (0..set.toks.len) |i| {
                const tok = set.toks.get(i);
                var pos: log.filePos = .{ .set = set, .i = tok.beg_i };
                pos.computeCoords();
                if (tok.kind < 128) try stdout.print(
                    "{d}:{d}\t{d}\t{s}\t{c}\n",
                    .{ pos.row, pos.col, i, tok.lexeme(set), tok.kind },
                ) else {
                    const tok_kind: token.Kind = @enumFromInt(tok.kind);
                    try stdout.print(
                        "{d}:{d}\t{d}\t{s}\t{}\n",
                        .{ pos.row, pos.col, i, tok.lexeme(set), tok_kind },
                    );
                }
            }
            try stdout.print("=== TOK: END ===\n", .{});
            try stdout.print("\n=== AST: BEG ===\n", .{});
        }

        try ast.parseTreeFromToks(stderr, set);

        if (debug_view) {
            try ast.printDebug(stdout, set);
            try stdout.print("=== AST: END ===\n", .{});
        } else {
            const use_ansi_clr = args_parsed.print.clr or
                (ansi.shouldUse() and !args_parsed.print.noclr);
            if (use_ansi_clr) {
                try ast.printNicely(stdout, .ansi_clr_enabled, set);
            } else {
                try ast.printNicely(stdout, .ansi_clr_disabled, set);
            }
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
