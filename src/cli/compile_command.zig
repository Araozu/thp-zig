const std = @import("std");

const command_help =
    \\THP v{}.{}.{}
    \\
    \\compile: Compiles a single file into bytecode
    \\
    \\ thp compile <file> [options]
    \\     c       <file> [options]
    \\
    \\ [options]
    \\
    \\ -o <output>   - specifies the output file
    \\ -p            - compiles the file in place, output file is <file>.php
    \\
;

pub const CompileOptionsError = error{
    CompileMissingFilename,
    CompileMissingOutput,
    CompileInvalidOption,
};

pub const CompileOptions = struct {
    filename: [:0]const u8,
    output: ?[]const u8,
    in_place: bool,

    /// Parses the compile command line arguments.
    ///
    /// <compile> options
    ///
    /// thp c <file>             - compiles a single file, outputs to stdout
    ///       <file> -o <output> - compiles a single file, outputs to <output>
    ///       <file> -p          - compiles a single file in place. the output file
    ///                            is the input file with .php extension
    pub fn parse(args: *std.process.ArgIterator) CompileOptionsError!CompileOptions {
        // get file name
        const filename = args.next() orelse return CompileOptionsError.CompileMissingFilename;

        // TODO: parse -o and -i flags

        return CompileOptions{
            .filename = filename,
            .output = null,
            .in_place = false,
        };
    }

    pub fn printUsage(version: std.SemanticVersion) void {
        std.debug.print(command_help, .{ version.major, version.minor, version.patch });
    }
};
