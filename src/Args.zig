const std = @import("std");

err_writer: std.fs.File.Writer,
exe_kind: Kind = .boolean,
flags: []*Flag = &.{},
result: Result = .{ .single = "" },
single_pos: ?[]const u8 = null,

const Kind = enum { boolean, single, multi };

pub const Flag = struct {
    name: []const u8,
    kind: Kind = .boolean,
    is_present: bool = false,
    result: Result = undefined,
};

const Result = union {
    single: []const u8,
    multi: struct { beg_i: usize = 0, end_i: usize = 0 },
};

pub fn parse(self: *@This(), argv: []const []const u8) !void {
    if (argv.len < 2) unreachable;

    var i: usize = 1;
    var arg = argv[i];
    while (i < argv.len) : ({
        i += 1;
        arg = argv[i];
    }) {
        if (arg.len == 1 or arg[0] != '-') {
            switch (self.exe_kind) {
                .boolean => return self.err(
                    "unexpected positional argument '{s}'",
                    .{arg},
                ),
                .single => {
                    if (self.result.single.len != 0) return self.err(
                        "unexpected positional argument '{s}'",
                        .{arg},
                    );
                    self.result.single = arg;
                },
                .multi => {
                    if (self.result.multi.beg_i == 0) {
                        self.result.multi.beg_i = i;
                        self.result.multi.end_i = i + 1;
                        continue;
                    }
                    if (self.result.multi.end_i < i) return self.err(
                        "unexpected positional argument '{s}'",
                        .{arg},
                    );
                    self.result.multi.end_i += 1;
                },
            }
            continue;
        }

        const flag = blk: for (self.flags) |f| {
            const single_dash = arg[0] == '-' and
                std.mem.eql(u8, arg[1..], f.name);
            const double_dash = arg.len > 2 and
                std.mem.eql(u8, arg[0..2], "--") and
                std.mem.eql(u8, arg[2..], f.name);
            if (!single_dash and !double_dash) continue;

            f.is_present = true;
            break :blk f;
        } else return self.err("invalid flag '{s}'", .{arg});

        switch (flag.kind) {
            .boolean => {},
            .single => {
                if (i + 1 == argv.len or argv[i + 1][0] == '-') {
                    return self.err(
                        "expected positional argument after '{s}'",
                        .{arg},
                    );
                }

                flag.result.multi.beg_i = i + 1;
                flag.result.multi.end_i = i + 2;

                i += 1;
                arg = argv[i];
                while (i < argv.len) : (arg = argv[i]) {
                    if (arg[0] == '-') {
                        i -= 1;
                        break;
                    }
                    flag.result.multi.end_i = i + 1;
                }
            },
            .multi => {},
        }
    }
}

fn err(self: @This(), comptime fmt: []const u8, args: anytype) anyerror {
    _ = try self.err_writer.print(fmt ++ "\n", args);
    return error{InvalidUsage}.InvalidUsage;
}
