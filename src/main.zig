const Args = @import("Args.zig");
const Context = @import("Context.zig");
const std = @import("std");

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

    if (argv.len == 1) {
        _ = try stderr_writer.write(help_text);
        return error{InvalidUsage}.InvalidUsage;
    }

    var debug_flag = Args.Flag{ .name = "debug" };
    var help_flag_short = Args.Flag{ .name = "h" };
    var help_flag_long = Args.Flag{ .name = "help" };
    var version_flag = Args.Flag{ .name = "version" };
    var flags = [_]*Args.Flag{
        &debug_flag,
        &help_flag_short,
        &help_flag_long,
        &version_flag,
    };
    var args = Args{
        .err_writer = stderr_writer,
        .exe_kind = .single,
        .flags = &flags,
    };
    try args.parse(argv);

    if (help_flag_short.is_present or help_flag_long.is_present) {
        _ = try stdout_writer.write(help_text);
        return;
    }

    if (version_flag.is_present) {
        _ = try stdout_writer.write(version_text);
        return;
    }

    const ctx = Context.init(.{
        .allocator = arena.allocator(),
        .writer = stdout_writer,
        .err_writer = stderr_writer,
    });
    _ = ctx;
}

const version_text = "nota (version 0.4-dev)\n";
const help_text = version_text ++
    \\
    \\Usage: nota <file>
    \\
    \\Options:
    \\      --debug
    \\        Print debug information
    \\  -h, --help
    \\        Print this help and exit
    \\      --version
    \\        Print version information and exit
    \\
;
