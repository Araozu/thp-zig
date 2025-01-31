const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create options module for conditional compilation
    const executionTracing = b.option(bool, "tracing", "enable execution tracing") orelse false;
    const json_serialization = b.option(bool, "json", "enable JSON serialization of the compiler outputs") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "tracing", executionTracing);
    options.addOption(bool, "json", json_serialization);

    // Create the options module that will be shared
    const options_module = options.createModule();

    const exe = b.addExecutable(.{
        .name = "thp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add options to executable
    exe.root_module.addImport("config", options_module);

    //
    // Error handling module
    //
    const error_module = b.addModule("errors", .{
        .root_source_file = b.path("src/errors/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    error_module.addImport("config", options_module);
    exe.root_module.addImport("errors", error_module);

    //
    // Context module
    //
    const context_module = b.addModule("context", .{
        .root_source_file = b.path("src/context/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    context_module.addImport("config", options_module);
    exe.root_module.addImport("context", context_module);

    //
    // Lexic module
    //
    const lexic_module = b.addModule("lexic", .{
        .root_source_file = b.path("src/01_lexic/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lexic_module.addImport("config", options_module);
    lexic_module.addImport("errors", error_module);
    lexic_module.addImport("context", context_module);
    exe.root_module.addImport("lexic", lexic_module);

    //
    // Syntax module
    //
    const syntax_module = b.addModule("syntax", .{
        .root_source_file = b.path("src/02_syntax/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    syntax_module.addImport("config", options_module);
    syntax_module.addImport("lexic", lexic_module);
    syntax_module.addImport("errors", error_module);
    syntax_module.addImport("context", context_module);
    exe.root_module.addImport("syntax", syntax_module);

    // Install step
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Pass arguments if any
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("config", options_module);
    exe_unit_tests.root_module.addImport("lexic", lexic_module);
    exe_unit_tests.root_module.addImport("syntax", syntax_module);
    exe_unit_tests.root_module.addImport("errors", error_module);
    exe_unit_tests.root_module.addImport("context", context_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run ALL unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Add dependencies for unit testing
    const files = [_][]const u8{
        "src/01_lexic/root.zig",
        "src/02_syntax/root.zig",
        "src/errors/root.zig",
    };
    for (files) |file| {
        const file_unit_test = b.addTest(.{
            .root_source_file = b.path(file),
            .target = target,
            .optimize = optimize,
        });
        file_unit_test.root_module.addImport("config", options_module);
        file_unit_test.root_module.addImport("lexic", lexic_module);
        file_unit_test.root_module.addImport("syntax", syntax_module);
        file_unit_test.root_module.addImport("errors", error_module);
        file_unit_test.root_module.addImport("context", context_module);

        var test_artifact = b.addRunArtifact(file_unit_test);
        test_step.dependOn(&test_artifact.step);
    }
}
