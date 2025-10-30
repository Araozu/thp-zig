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
//!
//! thp lex     - lexes a single file, outputs tokens to stdout as json
//!
//! <compile> options
//!
//! thp c <file>             - compiles a single file, outputs to stdout
//!       <file> -o <output> - compiles a single file, outputs to <output>
//!       <file> -p          - compiles a single file in place. the output file is the input file with .php extension

const std = @import("std");
const config = @import("config");

pub const compile_command = @import("./compile_command.zig");
pub const compile_runner = @import("./runners/compile_runner.zig");
pub const lex_runner = @import("./runners/lex_runner.zig");

/// Represents the possible command line arguments.
pub const CliArgs = union(enum) {
    None,
    Dev,
    Build,
    Init,
    Compile: compile_command.CompileOptions,
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
            } else if (std.mem.eql(u8, arg, "lex")) {
                return .Lex;
            }

            // Other cases
        }

        return .None;
    }

    /// Returns a usage string for the command line interface.
    pub fn usage() []const u8 {
        return 
        \\thp <command> [options]
        \\
        \\thp         - starts the REPL?
        \\thp dev     - starts the dev server, picking up the config file
        \\thp build   - builds the project based on the config file
        \\
        \\thp init    - creates a new config file
        \\thp compile - compiles a single file, outputs to stdout
        \\    c
        \\
        \\thp lex     - lexes a single file, outputs tokens to stdout as json
        \\
        \\<compile> options
        \\
        \\thp c <file>             - compiles a single file, outputs to stdout
        \\      <file> -o <output> - compiles a single file, outputs to <output>
        \\      <file> -p          - compiles a single file in place. the output file is the input file with .php extension
        ;
    }
};
