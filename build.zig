const std = @import("std");

pub fn build(b: *std.Build) !void {
    const main_path = b.path("./src/main.zig");
    const mod_path = b.path("./src/root.zig");
    const target = b.standardTargetOptions(.{});

    // install
    const exe_mod = b.createModule(.{
        .root_source_file = main_path,
        .target = target,
        .optimize = .ReleaseFast,
    });
    const exe = b.addExecutable(.{
        .name = "rmd",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // wasm
    const wasm_mod = b.createModule(.{
        .root_source_file = mod_path,
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseFast,
    });
    const wasm = b.addExecutable(.{
        .name = "rmd",
        .root_module = wasm_mod,
    });
    wasm.rdynamic = true;
    wasm.entry = .disabled;
    const wasm_exe = b.addInstallArtifact(wasm, .{});
    const wasm_step = b.step("wasm", "Build for WebAssembly");
    wasm_step.dependOn(&wasm_exe.step);

    // run
    const debug_mod = b.createModule(.{
        .root_source_file = main_path,
        .target = target,
        .optimize = .Debug,
        .valgrind = true,
    });
    const debug_exe = b.addExecutable(.{
        .name = "rmd-debug",
        .root_module = debug_mod,
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
        .root_module = debug_mod,
        .filters = if (b.args) |args| &.{args[0]} else &.{},
    });
    const test_cmd = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_cmd.step);

    // testw
    const wasm_test_cmd = b.addSystemCommand(&.{ "deno", "test", "--allow-read" });
    wasm_test_cmd.step.dependOn(&wasm_exe.step);
    const testwasm_step = b.step("testw", "Run WASM tests (requires Deno)");
    testwasm_step.dependOn(&wasm_test_cmd.step);
}
