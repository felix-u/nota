const std = @import("std");
const token = @import("token.zig");

pub fn main() !void {
    // Allocator setup.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Args setup.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        std.debug.print("nota: expected file\n", .{});
        std.os.exit(1);
    }

    // Read file into buffer.
    const filepath = args[1];
    const infile = try std.fs.cwd().openFile(filepath, .{ .mode = .read_only });
    defer infile.close();
    const filebuf = try infile.readToEndAlloc(allocator, 10e6);
    defer allocator.free(filebuf);

    // Placeholder.
    var placeholder: token.TokenList = undefined;
    try token.parse(filebuf, &placeholder);
}
