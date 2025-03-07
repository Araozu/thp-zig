const std = @import("std");

fn create_module(
    path: []const u8,
    b: *std.Build,
    t: std.Build.ResolvedTarget,
    o: std.builtin.OptimizeMode,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(path),
        .target = t,
        .optimize = o,
    });
}

pub fn build(b: *std.Build) void {
    // Standard target options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create options module for conditional compilation
    const executionTracing = b.option(bool, "tracing", "enable execution tracing") orelse false;
    const json_serialization = b.option(bool, "json", "enable JSON serialization of the compiler outputs") orelse false;
    const no_bin = b.option(bool, "no-bin", "skip emitting binary") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "tracing", executionTracing);
    options.addOption(bool, "json", json_serialization);

    // Create the options module that will be shared
    const options_module = options.createModule();

    //
    // Modules
    //
    const error_module = create_module("src/error_context/root.zig", b, target, optimize);
    const lexic_module = create_module("src/01_lexic/root.zig", b, target, optimize);
    const syntax_module = create_module("src/02_syntax/root.zig", b, target, optimize);
    const semantic_module = create_module("src/03_semantic/root.zig", b, target, optimize);
    const root_module = create_module("src/main.zig", b, target, optimize);

    //
    // set up module dependencies
    //
    error_module.addImport("config", options_module);
    //
    lexic_module.addImport("config", options_module);
    lexic_module.addImport("context", error_module);
    //
    syntax_module.addImport("config", options_module);
    syntax_module.addImport("context", error_module);
    syntax_module.addImport("lexic", lexic_module);
    //
    semantic_module.addImport("config", options_module);
    semantic_module.addImport("context", error_module);
    semantic_module.addImport("lexic", lexic_module);
    semantic_module.addImport("syntax", syntax_module);
    //
    root_module.addImport("config", options_module);
    root_module.addImport("context", error_module);
    root_module.addImport("lexic", lexic_module);
    root_module.addImport("syntax", syntax_module);
    root_module.addImport("semantic", semantic_module);

    //
    // Main executable
    //
    const exe = b.addExecutable(.{
        .name = "thp",
        .root_module = root_module,
    });

    // If using -Dno-bin, use the x86-backend for fast builds
    if (no_bin) {
        exe.use_llvm = false;
        b.getInstallStep().dependOn(&exe.step);
        return;
    } else {
        b.installArtifact(exe);
    }

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

    //
    // Unit tests
    //

    const error_module_tests = b.addTest(.{ .name = "error_module", .root_module = error_module });
    const lexic_module_tests = b.addTest(.{ .name = "lexic", .root_module = lexic_module });
    const syntax_module_tests = b.addTest(.{ .name = "syntax", .root_module = syntax_module });
    const semantic_module_tests = b.addTest(.{ .name = "semantic", .root_module = semantic_module });
    const root_module_tests = b.addTest(.{ .name = "root", .root_module = root_module });

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&b.addRunArtifact(error_module_tests).step);
    test_step.dependOn(&b.addRunArtifact(lexic_module_tests).step);
    test_step.dependOn(&b.addRunArtifact(syntax_module_tests).step);
    test_step.dependOn(&b.addRunArtifact(semantic_module_tests).step);
    test_step.dependOn(&b.addRunArtifact(root_module_tests).step);
}
