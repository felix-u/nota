const ansi = @import("ansi.zig");
const args = @import("args.zig");
const Context = @import("Context.zig");
const std = @import("std");
const token = @import("Token.zig");

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
            },
        }},
    }) orelse return;
    defer allocator.destroy(args_parsed);
    const arg = args_parsed.nota;

    var ctx = Context{
        .allocator = allocator,
        .writer = stdout_writer,
        .err_writer = stderr_writer,
    };
    try ctx.initFromFilepath(args_parsed.nota.pos);

    const is_colour_on = std.io.tty.detectConfig(stdout) != .no_color;
    try ctx.parse(arg.debug, is_colour_on);
}
