const Context = @import("Context.zig");
const Procedure = @import("Procedure.zig");
const Stack = @import("Stack.zig");
const std = @import("std");
const Token = @import("Token.zig");

operation: Operation,
operand: Operand = .{ .none = undefined },

const Operation = enum(u8) {
    noop = 0,
    @"+",
    @"-",
    @"*",
    @"/",
    @"=",
    drop,
    dup,
    exit,
    jump,
    @"jump-relative",
    @"jump-if-true",
    @"jump-if-true-relative",
    not,
    println,
    push,
    @"push-jumpstack-relative",
    @"return",
};

pub const Operand = union(Type) {
    // TODO: stack as type here? as enum to choose parameter or jump stack
    none: void,
    boolean: bool,
    int: isize,
    string: []const u8,
    pub const Type = enum { none, boolean, int, string };
};

pub const List = std.ArrayList(@This());

pub fn fromToks(ctx: *Context) !void {
    ctx.instructions = try std.ArrayList(@This()).initCapacity(
        ctx.allocator,
        ctx.toks.items.len,
    );

    ctx.comptime_stack = Stack.init(ctx.allocator);

    ctx.procedures_map = Procedure.Map.init(ctx.allocator);
    ctx.procedures_list = Procedure.List.init(ctx.allocator);
    try Procedure.putBuiltins(ctx);
    ctx.procedures_total_instruction_count = 0;

    const i = &ctx.tok_i;
    i.* = 0;
    while (i.* < ctx.toks.items.len) : (i.* += 1) {
        try fromTok(ctx, i.*);
    }

    ctx.instruction_stream = List.init(ctx.allocator);
    for (ctx.procedures_list.items) |procedure| {
        try ctx.instruction_stream.appendSlice(procedure.instructions.items);
    }
    ctx.instruction_start_point = @intCast(ctx.instruction_stream.items.len);
    try ctx.instruction_stream.appendSlice(ctx.instructions.items);
}

pub fn fromTok(ctx: *Context, tok_i: u32) !void {
    const tok = ctx.toks.items[tok_i];
    const lexeme = ctx.lexeme(@intCast(tok_i));
    switch (tok.kind) {
        .number => {
            const value = try std.fmt.parseInt(isize, lexeme, 0);
            try ctx.instructions.append(
                .{ .operation = .push, .operand = .{ .int = value } },
            );
        },
        .string => {
            try ctx.instructions.append(
                .{ .operation = .push, .operand = .{ .string = lexeme } },
            );
        },
        .symbol => {
            var procedure = ctx.procedures_map.get(lexeme) orelse {
                return ctx.err("no such procedure '{s}'", .{lexeme});
            };

            if (procedure.@"comptime") |comptime_fn| {
                try comptime_fn(ctx);
            } else if (procedure.macro) |instructions| {
                _ = instructions;
                @panic("unimplemented");
            } else {
                if (procedure.compiled == null) {
                    procedure.compiled =
                        ctx.procedures_total_instruction_count;

                    try ctx.procedures_list.append(procedure);
                    ctx.procedures_map.putAssumeCapacity(lexeme, procedure);
                    ctx.procedures_total_instruction_count += @intCast(
                        procedure.instructions.items.len,
                    );
                }
                const continuation_instruction_count = 3;
                try ctx.instructions.appendSlice(&.{
                    .{
                        .operation = .push,
                        .operand = .{ .int = continuation_instruction_count },
                    },
                    .{ .operation = .@"push-jumpstack-relative" },
                    .{
                        .operation = .push,
                        .operand = .{ .int = procedure.compiled.? },
                    },
                    .{ .operation = .jump },
                });
            }
        },
    }
}

pub fn printAll(ctx: *const Context) !void {
    _ = try ctx.writer.write("Instructions:\n");
    try ctx.writer.print("  START {d}\n", .{ctx.instruction_start_point});
    const instructions = ctx.instruction_stream.items;
    for (instructions, 0..instructions.len) |instruct, i| {
        try ctx.writer.print(
            "{d}\t{any}\t{any}\n",
            .{ i, instruct.operand, instruct.operation },
        );
    }
}
