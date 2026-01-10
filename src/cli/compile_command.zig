const std = @import("std");

const command_help =
    \\compile: Compiles a single file into bytecode
    \\
    \\ thp compile <file> [options]
    \\     c       <file> [options]
    \\
    \\ [options]
    \\
    \\ -o <output>   - specifies the output file
    \\ -p            - compiles the file in place, output file is <file>.php
    \\ -i, --stdin   - reads the source code from stdin
    \\
;

pub const CompileOptionsError = error{
    CompileMissingFilename,
    CompileMissingOutput,
    CompileInvalidOption,
};

pub const CompileOptions = struct {
    filename: ?[:0]const u8,
    from_stdin: bool,
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
    ///       -i, --stdin        - reads the source code from stdin
    pub fn parse(args: *std.process.ArgIterator) CompileOptionsError!CompileOptions {
        var filename: ?[:0]const u8 = null;
        var from_stdin = false;
        var output: ?[]const u8 = null;
        var in_place = false;

        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "-o")) {
                output = args.next() orelse return CompileOptionsError.CompileMissingOutput;
            } else if (std.mem.eql(u8, arg, "-p")) {
                in_place = true;
            } else if (std.mem.eql(u8, arg, "-i") or std.mem.eql(u8, arg, "--stdin")) {
                from_stdin = true;
            } else if (arg[0] == '-') {
                return CompileOptionsError.CompileInvalidOption;
            } else {
                if (filename != null) {
                    return CompileOptionsError.CompileInvalidOption;
                }
                filename = arg;
            }
        }

        if (filename == null and !from_stdin) {
            return CompileOptionsError.CompileMissingFilename;
        }

        if (filename != null and from_stdin) {
            return CompileOptionsError.CompileInvalidOption;
        }

        return CompileOptions{
            .filename = filename,
            .from_stdin = from_stdin,
            .output = output,
            .in_place = in_place,
        };
    }

    pub fn usage() []const u8 {
        return command_help;
    }
};
