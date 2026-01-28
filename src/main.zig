const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");
const semantic = @import("semantic");
const codegen = @import("codegen");
const err_ctx = @import("context");
const parser_ctx = syntax.context;

const cli_interface = @import("./cli/interface.zig");

const config = @import("config");
const tracing = config.tracing;
const json = config.json;

pub const thp_version: std.SemanticVersion = .{
    .major = 0,
    .minor = 0,
    .patch = 4,
};

pub fn main() !void {
    // just run the CLI
    var args = std.process.args();
    defer args.deinit();

    // std.debug.print("THP v{}.{}.{}\n\n", .{ thp_version.major, thp_version.minor, thp_version.patch });

    const cli_args = cli_interface.CliArgs.parse(&args) catch |err| switch (err) {
        error.CompileMissingFilename => {
            std.debug.print("{s}\n\n", .{cli_interface.compile_command.CompileOptions.usage()});
            std.debug.print("Error: Missing <file> for compile command.\n", .{});
            return;
        },
        error.CompileMissingOutput => {
            std.debug.print("{s}\n\n", .{cli_interface.compile_command.CompileOptions.usage()});
            std.debug.print("Error: Missing <output> for -o option.\n", .{});
            return;
        },
        error.CompileInvalidOption => {
            std.debug.print("{s}\n\n", .{cli_interface.compile_command.CompileOptions.usage()});
            std.debug.print("Error: Invalid option for compile command.\n", .{});
            return;
        },
        error.RunMissingFilename => {
            std.debug.print("{s}\n\n", .{cli_interface.run_command.RunOptions.usage()});
            std.debug.print("Error: Missing <file> for run command.\n", .{});
            return;
        },
    };

    switch (cli_args) {
        .Compile => |opts| {
            _ = try cli_interface.compile_runner.run(&opts);
        },
        .Run => |opts| {
            _ = try cli_interface.run_runner.run(&opts);
        },
        .Lex => {
            _ = try cli_interface.lex_runner.run();
        },
        else => {
            std.debug.print("{s}\n", .{cli_interface.CliArgs.usage()});
            return;
        },
    }

    // try repl();
}

inline fn trace_header() void {
    std.debug.print("  |TRACE> ", .{});
}
