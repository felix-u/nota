const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nota",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimise,
    });

    b.installArtifact(exe);
}
