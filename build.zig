const std = @import("std");

pub fn build(b: *std.Build) !void {
    const main_path = b.path("./src/main.zig");
    const mod_path = b.path("./src/root.zig");
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mdz = b.addModule("mdz", .{
        .root_source_file = mod_path,
        .target = target,
        .optimize = optimize,
    });

    // install
    const exe = b.addExecutable(.{
        .name = "mdz",
        .root_module = b.createModule(.{
            .root_source_file = main_path,
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "mdz", .module = mdz },
            },
        }),
    });
    b.installArtifact(exe);

    // wasm
    const wasm = b.addExecutable(.{
        .name = "mdz",
        .root_module = b.createModule(.{
            .root_source_file = mod_path,
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = .ReleaseFast,
        }),
    });
    wasm.rdynamic = true;
    wasm.entry = .disabled;
    const wasm_exe = b.addInstallArtifact(wasm, .{});
    const wasm_step = b.step("wasm", "Build for WebAssembly");
    wasm_step.dependOn(&wasm_exe.step);

    // run
    const debug_exe = b.addExecutable(.{
        .name = "mdz-debug",
        .root_module = b.createModule(.{
            .root_source_file = main_path,
            .target = target,
            .optimize = .Debug,
            .valgrind = true,
            .imports = &.{
                .{ .name = "mdz", .module = mdz },
            },
        }),
    });
    const debug_exe_art = b.addInstallArtifact(debug_exe, .{});
    const run_debug_cmd = b.addRunArtifact(debug_exe);
    if (b.args) |args| {
        run_debug_cmd.addArgs(args);
    }
    const run_debug_step = b.step("run", "Run the debug app");
    run_debug_step.dependOn(&run_debug_cmd.step);
    run_debug_step.dependOn(&debug_exe_art.step);

    // test
    const test_step = b.step("test", "Run tests");
    const test_exe = b.addTest(.{
        .root_module = mdz,
        .filters = if (b.args) |args| &.{args[0]} else &.{},
    });
    const test_cmd = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_cmd.step);

    // check
    const check = b.step("check", "Check if mdz compiles");
    check.dependOn(&debug_exe.step);
}
