const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "thp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    //
    // Error handling module
    //
    const error_module = b.addModule("errors", .{
        .root_source_file = b.path("src/errors/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("errors", error_module);

    //
    // Lexic module
    //
    const lexic_module = b.addModule("lexic", .{
        .root_source_file = b.path("src/01_lexic/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("lexic", lexic_module);
    lexic_module.addImport("errors", error_module);

    //
    // Syntax module
    //
    const syntax_module = b.addModule("syntax", .{
        .root_source_file = b.path("src/02_syntax/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("syntax", syntax_module);
    syntax_module.addImport("lexic", lexic_module);
    syntax_module.addImport("errors", error_module);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("lexic", lexic_module);
    exe_unit_tests.root_module.addImport("syntax", syntax_module);
    exe_unit_tests.root_module.addImport("errors", error_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run ALL unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Add dependencies for unit testing
    const files = [_][]const u8{
        "src/01_lexic/root.zig",
        "src/02_syntax/root.zig",
    };
    for (files) |file| {
        const file_unit_test = b.addTest(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
        });
        file_unit_test.root_module.addImport("lexic", lexic_module);
        file_unit_test.root_module.addImport("syntax", syntax_module);
        file_unit_test.root_module.addImport("errors", error_module);

        var test_artifact = b.addRunArtifact(file_unit_test);
        test_step.dependOn(&test_artifact.step);
    }
}
