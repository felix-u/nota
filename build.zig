const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe_name = "nota";
    const exe_version = "0.4-dev";
    const root_source_file = "src/main.zig";

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const debug_exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .Debug,
        .linkage = .static,
    });
    debug_exe.strip = false;
    const debug_step = b.step("debug", "Build [Debug]");
    debug_step.dependOn(&b.addInstallArtifact(debug_exe).step);

    const release_exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .ReleaseFast,
        .linkage = .static,
    });
    release_exe.strip = true;
    const release_step = b.step("release", "Build [ReleaseFast]");
    release_step.dependOn(&b.addInstallArtifact(release_exe).step);

    const cross_step = b.step("cross", "Build for targets [ReleaseSafe]");
    const target_arches = [_][]const u8{
        "x86_64", "aarch64",
    };
    const target_oses = [_][]const u8{
        "linux", "macos", "windows",
    };
    inline for (target_arches) |target_arch| {
        inline for (target_oses) |target_os| {
            const triple = target_arch ++ "-" ++ target_os;
            const cross_target = std.zig.CrossTarget.parse(.{ .arch_os_abi = triple }) catch unreachable;
            makeStep(b, cross_step, .ReleaseFast, .{
                .name = b.fmt("{s}-v{s}-{s}", .{ exe_name, exe_version, triple }),
                .root_source_file = .{ .path = root_source_file },
                .target = cross_target,
            });
        }
    }
}

fn makeStep(
    b: *std.Build,
    step: *std.Build.Step,
    comptime mode: std.builtin.Mode,
    options: std.Build.ExecutableOptions,
) void {
    const exe = b.addExecutable(.{
        .name = options.name,
        .root_source_file = options.root_source_file,
        .target = options.target,
        .optimize = mode,
        .linkage = options.linkage,
    });
    exe.strip = if (mode == .Debug) false else true;
    step.dependOn(&b.addInstallArtifact(exe).step);
}
