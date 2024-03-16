const Context = @import("Context.zig");
const Instruction = @import("Instruction.zig");
const std = @import("std");

elements: std.ArrayList(Element),

const StackError = error{ Underflow, TypeMismatch };
const Element = Instruction.Operand;
const Type = Instruction.Operand.Type;

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{ .elements = std.ArrayList(Element).init(allocator) };
}

pub fn pop(self: *@This(), ctx: *Context) !Element {
    const popped = self.elements.popOrNull() orelse
        return ctx.err("stack underflow while executing procedure:", .{});
    return popped;
}

pub fn popType(
    self: *@This(),
    ctx: *Context,
    comptime typ: Type,
    comptime return_typ: type, // TODO infer return type from `typ`
) !return_typ {
    const popped = self.elements.popOrNull() orelse
        return ctx.err("stack underflow", .{});
    return switch (popped) {
        typ => |value| value,
        else => |value| ctx.err(
            "expected '{s}', found '{s}' while executing procedure:",
            .{ @tagName(typ), @tagName(value) },
        ),
    };
}

pub fn push(self: *@This(), element: Element) !void {
    try self.elements.append(element);
}
