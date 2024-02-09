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
        try args.parseAlloc(allocator, stdout_writer, stderr_writer, argv, .{
        .desc = "general-purpose declarative notation language",
        .ver = "0.4-dev",
        .usage = "<command> <file> [options]",
        .cmds = &.{.{
            .name = "nota",
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
            },
        }},
    }) orelse return;
    defer allocator.destroy(args_parsed);
    const arg = args_parsed.nota;

    var ctx = parse.Context{
        .allocator = allocator,
        .writer = stdout_writer,
        .err_writer = stderr_writer,
    };
    try ctx.initFromPath(args_parsed.nota.pos);

    const is_colour_on = std.io.tty.detectConfig(stdout) != .no_color;
    try ctx.parseAndPrint(arg.debug, is_colour_on);
}
