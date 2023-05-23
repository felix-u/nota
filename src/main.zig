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
    const filebuf = try infile.readToEndAlloc(allocator, std.math.maxInt(u32));
    defer allocator.free(filebuf);

    var token_list = token.TokenList{};
    var pos: token.ParsePosition = .{ .buf = filebuf };
    try token.parse(&pos, &token_list, allocator);

    // Print tokens (for now).
    for (0..token_list.len) |i| {
        const item = token_list.get(i);
        const position = item.filePosition(filebuf);
        const lexeme = item.lexeme(filebuf);
        // std.debug.print("{d}:{d}\t{}\n", .{ position.line, position.col, item.token });
        std.debug.print("{d}:{d}\t\"{s}\"\t{}\n", .{ position.line, position.col, lexeme, item.token });
        // std.debug.print("{d}\t{}\n", .{ item.idx, item.token });
    }
}
