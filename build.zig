const std = @import("std");

pub fn build(b: *std.Build) !void {
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
            .root_source_file = b.path("./src/main.zig"),
            .target = target,
            .optimize = optimize,
            .valgrind = optimize == .debug,
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
            .optimize = .small,
        }),
    });
    wasm.rdynamic = true;
    wasm.entry = .disabled;
    const wasm_exe = b.addInstallArtifact(wasm, .{});
    const wasm_step = b.step("wasm", "Build for WebAssembly");
    wasm_step.dependOn(&wasm_exe.step);

    // run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the debug app");
    run_step.dependOn(&run_cmd.step);

    // test
    const test_step = b.step("test", "Run tests");
    const test_filters = b.option([][]const u8, "test_filter", "Filter for tests") orelse &.{};
    const test_exe = b.addTest(.{
        .root_module = mdz,
        .filters = test_filters,
    });
    const test_cmd = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_cmd.step);

    // check
    const check = b.step("check", "Check if mdz compiles");
    check.dependOn(&exe.step);
}
