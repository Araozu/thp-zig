//! The THP command line interface.
//!
//! thp <command> [options]
//!
//! thp         - starts the REPL?
//! thp dev     - starts the dev server, picking up the config file
//! thp build   - builds the project based on the config file
//!
//! thp init    - creates a new config file
//! thp compile - compiles a single file, outputs to stdout
//!     c
//! thp run     - compiles and executes a single file in the VM
//!     r
//!
//! thp lex     - lexes a single file, outputs tokens to stdout as json
//!
//! <compile> options
//!
//! thp c <file>             - compiles a single file, outputs to stdout
//!       <file> -o <output> - compiles a single file, outputs to <output>
//!       <file> -p          - compiles a single file in place. the output file is the input file with .php extension
//!
//! <run> options
//!
//! thp r <file>             - compiles and executes a single file in the VM

const std = @import("std");
const config = @import("config");

pub const compile_command = @import("./compile_command.zig");
pub const compile_runner = @import("./runners/compile_runner.zig");
pub const run_command = @import("./run_command.zig");
pub const run_runner = @import("./runners/run_runner.zig");
pub const lex_runner = @import("./runners/lex_runner.zig");

/// Represents the possible command line arguments.
pub const CliArgs = union(enum) {
    None,
    Dev,
    Build,
    Init,
    Compile: compile_command.CompileOptions,
    Run: run_command.RunOptions,
    Lex,

    /// Parses the command line arguments and returns the corresponding `CliArgs` variant.
    ///
    /// Expects a pointer to an argument iterator.
    /// This function assumes the first argument (the executable name) has not been consumed.
    pub fn parse(args: *std.process.ArgIterator) !CliArgs {
        // Ignore executable name
        _ = args.next();

        // check command
        if (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "compile") or std.mem.eql(u8, arg, "c")) {
                const compile_opts = try compile_command.CompileOptions.parse(args);
                return CliArgs{ .Compile = compile_opts };
            } else if (std.mem.eql(u8, arg, "run") or std.mem.eql(u8, arg, "r")) {
                const run_opts = try run_command.RunOptions.parse(args);
                return CliArgs{ .Run = run_opts };
            } else if (std.mem.eql(u8, arg, "lex")) {
                return .Lex;
            }

            // Other cases
        }

        return .None;
    }

    /// Prints the usage string for the command line interface.
    pub fn printUsage(version: std.SemanticVersion) void {
        std.debug.print(
            \\THP v{}.{}.{}
            \\
            \\thp <command> [options]
            \\
            \\thp         - starts the REPL?
            \\thp dev     - starts the dev server, picking up the config file
            \\thp build   - builds the project based on the config file
            \\
            \\thp init    - creates a new config file
            \\thp compile - compiles a single file, outputs to stdout
            \\    c
            \\thp run     - compiles and executes a single file in the VM
            \\    r
            \\
            \\thp lex     - lexes a single file, outputs tokens to stdout as json
            \\
            \\<compile> options
            \\
            \\thp c <file>             - compiles a single file, outputs to stdout
            \\      <file> -o <output> - compiles a single file, outputs to <output>
            \\      <file> -p          - compiles a single file in place. the output file is the input file with .php extension
            \\
            \\<run> options
            \\
            \\thp r <file>             - compiles and executes a single file in the VM
            \\
        , .{ version.major, version.minor, version.patch });
    }
};
