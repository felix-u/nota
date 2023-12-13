const ansi = @import("ansi.zig");
const args = @import("args.zig");
const ast = @import("ast.zig");
const parse = @import("parse.zig");
const std = @import("std");
const token = @import("token.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdout = std.io.getStdOut();
    const stdout_writer = stdout.writer();
    const stderr = std.io.getStdErr();
    const stderr_writer = stderr.writer();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const args_parsed =
        args.parseAlloc(allocator, stdout_writer, stderr_writer, argv, .{
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
                        .short = 'n',
                        .long = "node",
                        .desc = "Evaluate and print specified node",
                        .kind = .single_pos,
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

    var ctx = parse.Context{
        .allocator = allocator,
        .writer = stdout_writer,
        .err_writer = stderr_writer,
    };

    if (args_parsed.check.invoked) {
        try ctx.initFromPath(args_parsed.check.pos);
        try ctx.parse();
        std.os.exit(0);
    }

    if (args_parsed.print.invoked) {
        try ctx.initFromPath(args_parsed.print.pos);

        const debug_view = args_parsed.print.debug;
        if (debug_view) {
            try ctx.parseAndPrint(.debug, false);
        } else {
            const colour_supported =
                std.io.tty.detectConfig(stdout) != .no_color;
            const ansi_clr_mode = args_parsed.print.clr or
                (colour_supported and !args_parsed.print.noclr);
            try ctx.parseAndPrint(.pretty, ansi_clr_mode);
        }

        std.os.exit(0);
    }
}
