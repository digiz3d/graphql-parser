const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

pub fn build(b: *std.Build) void {
    for (targets) |target| {
        const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
        const lib_mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = b.resolveTargetQuery(target),
            .optimize = optimize,
        });

        const exe_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(target),
            .optimize = optimize,
        });

        const lib = b.addLibrary(.{
            .linkage = .static,
            .name = "gqlt",
            .root_module = lib_mod,
        });

        b.installArtifact(lib);

        const exe = b.addExecutable(.{
            .name = "gqlt",
            .root_module = exe_mod,
        });

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        const lib_unit_tests = b.addTest(.{
            .root_module = lib_mod,
        });

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

        const exe_unit_tests = b.addTest(.{
            .root_module = exe_mod,
        });

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
        test_step.dependOn(&run_exe_unit_tests.step);

        setupBenchmark(b, "benchmark", "benchmark/zig/main.zig", target, optimize, lib_mod);
        setupBenchmark(b, "micro-benchmark", "benchmark/zig/micro-main.zig", target, optimize, lib_mod);
    }
}

fn setupBenchmark(b: *std.Build, cliShortcut: []const u8, entrypoint: []const u8, target: std.Target.Query, optimize: std.builtin.OptimizeMode, lib_mod: *std.Build.Module) void {
    const benchmark_module = b.createModule(.{
        .root_source_file = b.path(entrypoint),
        .target = b.resolveTargetQuery(target),
        .optimize = optimize,
        .strip = true,
    });
    benchmark_module.addImport("gql", lib_mod);
    const benchmark_exe = b.addExecutable(.{
        .name = "main",
        .root_module = benchmark_module,
        .linkage = .static,
    });
    const benchmark_install = b.addInstallArtifact(benchmark_exe, .{
        .pdb_dir = .disabled,
        .dest_dir = .{ .override = .{ .custom = "../benchmark/zig" } },
    });
    const benchmark_step = b.step(cliShortcut, "Build benchmark");
    benchmark_step.dependOn(&benchmark_install.step);
}
