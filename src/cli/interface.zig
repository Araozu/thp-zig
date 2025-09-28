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

pub const CompileOptions = struct {
    filename: [:0]const u8,
    output: ?[]const u8,
    in_place: bool,
};

/// Represents the possible command line arguments.
pub const CliArgs = union(enum) {
    None,
    Dev,
    Build,
    Init,
    Compile: CompileOptions,
    Lex,

    /// Parses the command line arguments and returns the corresponding `CliArgs` variant.
    ///
    /// Expects a pointer to an argument iterator.
    /// This function assumes the first argument (the executable name) has not been consumed.
    ///
    /// If no arguments can be parsed, returns null.
    pub fn parse(args: *std.process.ArgIterator) ?CliArgs {
        // Ignore executable name
        _ = args.next();

        // check command
        if (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "compile") or std.mem.eql(u8, arg, "c")) {
                const compile_opts = parse_compile(args) orelse return null;
                return CliArgs{ .Compile = compile_opts };
            }
        }

        return null;
    }

    /// Parses the compile command line arguments.
    ///
    /// <compile> options
    ///
    /// thp c <file>             - compiles a single file, outputs to stdout
    ///       <file> -o <output> - compiles a single file, outputs to <output>
    ///       <file> -p          - compiles a single file in place. the output file
    ///                            is the input file with .php extension
    fn parse_compile(args: *std.process.ArgIterator) ?CompileOptions {
        // get file name
        const filename = args.next() orelse return null;

        // TODO: parse -o and -i flags

        return CompileOptions{
            .filename = filename,
            .output = null,
            .in_place = false,
        };
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
