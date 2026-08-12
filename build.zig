const std = @import("std");

pub fn build(b: *std.Build) void {
    const target: std.Build.ResolvedTarget = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});

    const use_lld = target.result.os.tag != .macos and
        target.result.os.tag != .freebsd and
        target.result.os.tag != .openbsd and
        target.result.os.tag != .netbsd;

    const mod: *std.Build.Module = b.addModule("matryoshka", .{
        .root_source_file = b.path("src/matryoshka.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = false,
    });

    const lib: *std.Build.Step.Compile = b.addLibrary(.{
        .name = "matryoshka",
        .linkage = .static,
        .root_module = mod,
        .use_llvm = true,
        .use_lld = use_lld,
    });

    b.installArtifact(lib);

    const tmod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("tests/matryoshka_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const emod: *std.Build.Module = b.addModule("examples", .{
        .root_source_file = b.path("examples/examples.zig"),
        .target = target,
        .optimize = optimize,
    });

    emod.addImport("matryoshka", mod);

    const smod: *std.Build.Module = b.addModule("stories", .{
        .root_source_file = b.path("stories/stories.zig"),
        .target = target,
        .optimize = optimize,
    });

    smod.addImport("matryoshka", mod);
    smod.addImport("examples", emod);

    tmod.addImport("matryoshka", mod);
    tmod.addImport("examples", emod);

    const lib_unit_tests: *std.Build.Step.Compile = b.addTest(.{
        .root_module = tmod,
        .use_llvm = true,
        .use_lld = use_lld,
    });

    b.installArtifact(lib_unit_tests);

    const run_lib_unit_tests: *std.Build.Step.Run = b.addRunArtifact(lib_unit_tests);

    const test_step: *std.Build.Step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Core surface: src/ plus the example code that calls Mbox/Pool directly.
    // Skips the layer* example trees — fast inner-loop compile check.
    const cmod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("examples/core_surface.zig"),
        .target = target,
        .optimize = optimize,
    });

    cmod.addImport("matryoshka", mod);

    const core_tests: *std.Build.Step.Compile = b.addTest(.{
        .root_module = cmod,
        .use_llvm = true,
        .use_lld = use_lld,
    });

    const run_core_tests: *std.Build.Step.Run = b.addRunArtifact(core_tests);

    const core_step: *std.Build.Step = b.step("core", "Build the core surface");
    core_step.dependOn(&run_core_tests.step);

    // Stories run on their own step, not as part of `test`. A story is a long
    // narrative program; it does not gate the unit-test suite.
    const stmod: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("tests/stories_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    stmod.addImport("matryoshka", mod);
    stmod.addImport("examples", emod);
    stmod.addImport("stories", smod);

    const stories_tests: *std.Build.Step.Compile = b.addTest(.{
        .root_module = stmod,
        .use_llvm = true,
        .use_lld = use_lld,
    });

    const run_stories_tests: *std.Build.Step.Run = b.addRunArtifact(stories_tests);

    const stories_step: *std.Build.Step = b.step("stories", "Run the stories");
    stories_step.dependOn(&run_stories_tests.step);

    // Documentation generation step
    const docs_step: *std.Build.Step = b.step("docs", "Generate API documentation");

    const apidocs_lib: *std.Build.Step.Compile = b.addObject(.{
        .name = "matryoshka",
        .root_module = mod,
        .use_llvm = true,
        .use_lld = use_lld,
    });

    const install_apidocs: *std.Build.Step.InstallDir = b.addInstallDirectory(.{
        .source_dir = apidocs_lib.getEmittedDocs(),
        .install_dir = .{ .custom = "../kitchen/docs" },
        .install_subdir = "apidocs",
    });

    docs_step.dependOn(&install_apidocs.step);
}
