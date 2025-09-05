const std = @import("std");

pub fn build(b: *std.Build) !void {
    const main_path = b.path("./src/main.zig");
    const target = b.standardTargetOptions(.{});
    const version = try std.SemanticVersion.parse("0.1.0");

    // install
    const exe_mod = b.createModule(.{
        .root_source_file = main_path,
        .target = target,
        .optimize = .ReleaseFast,
    });
    const exe = b.addExecutable(.{
        .name = "zigjot",
        .root_module = exe_mod,
        .version = version,
    });
    b.installArtifact(exe);

    // run
    const debug_mod = b.createModule(.{
        .root_source_file = main_path,
        .target = target,
        .optimize = .Debug,
        .valgrind = true,
    });
    const debug_exe = b.addExecutable(.{
        .name = "zigjot-debug",
        .root_module = debug_mod,
        .version = version,
    });
    const run_debug_cmd = b.addRunArtifact(debug_exe);
    if (b.args) |args| {
        run_debug_cmd.addArgs(args);
    }
    const run_debug_step = b.step("run", "Run the debug app");
    run_debug_step.dependOn(&run_debug_cmd.step);

    // test
    const test_step = b.step("test", "Run tests");
    const test_exe = b.addTest(.{ .root_module = debug_mod });
    const test_cmd = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_cmd.step);
}
