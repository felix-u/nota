const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});


    const cc_shared_flags = [_][]const u8 {
        "-std=c99",
        "-Wall",
        "-Wextra",
        "-pedantic",
        "-Wshadow",
        "-Wstrict-overflow",
        "-Wstrict-aliasing",
        // libs
        "-lm",
    };
    const cc_debug_flags = cc_shared_flags ++ .{
        "-g",
        "-Og",
        "-ggdb",
    };
    const cc_release_flags = cc_shared_flags ++ .{
        "-O3",
        "-s",
    };


    const exe = b.addExecutable(.{
        .name = "nota",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile("src/main.c", &cc_shared_flags);
    exe.linkLibC();
    exe.install();


    const debug_step = b.step("debug", "build debug exe");
    const debug_exe = b.addExecutable(.{
        .name = "nota",
        .target = target,
        .optimize = .Debug,
    });
    debug_exe.addCSourceFile("src/main.c", &cc_debug_flags);
    debug_exe.linkLibC();
    debug_step.dependOn(&b.addInstallArtifact(debug_exe).step);

    const release_step = b.step("release", "build release exe");
    const release_exe = b.addExecutable(.{
        .name = "nota",
        .target = target,
        .optimize = .ReleaseFast,
    });
    release_exe.addCSourceFile("src/main.c", &cc_release_flags);
    release_exe.linkLibC();
    release_exe.disable_sanitize_c = true;
    release_exe.strip = true;
    release_step.dependOn(&b.addInstallArtifact(release_exe).step);


    const cross_step = b.step("cross", "cross-compile for all targets");
    const triples = [_][]const u8 {
        "x86_64-windows",
        "aarch64-windows",
        "x86_64-linux-musl",
        "aarch64-linux-musl",
        "x86_64-macos",
        "aarch64-macos",
    };
    for (triples) |triple| {
        const cross_target =
            std.zig.CrossTarget.parse(.{ .arch_os_abi = triple }) catch unreachable;
        const cross_exe = b.addExecutable(.{
            .name = b.fmt("nota-{s}", .{triple}),
            .target = cross_target,
            .optimize = .ReleaseSafe,
        });
        cross_exe.addCSourceFile("src/main.c", &(cc_shared_flags ++ .{ "-static" }));
        cross_exe.disable_sanitize_c = true;
        cross_exe.strip = true;
        cross_exe.linkLibC();
        cross_step.dependOn(&b.addInstallArtifact(cross_exe).step);
    }

}
