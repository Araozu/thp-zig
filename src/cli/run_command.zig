const std = @import("std");

const command_help =
    \\THP v{}.{}.{}
    \\
    \\run: Compiles and executes a single file in the VM
    \\
    \\ thp run <file>
    \\
;

pub const RunOptionsError = error{
    RunMissingFilename,
};

pub const RunOptions = struct {
    filename: [:0]const u8,

    /// Parses the run command line arguments.
    ///
    /// <run> options
    ///
    /// thp run <file>  - compiles and executes a single file in the VM
    pub fn parse(args: *std.process.ArgIterator) RunOptionsError!RunOptions {
        // get file name
        const filename = args.next() orelse return RunOptionsError.RunMissingFilename;

        return RunOptions{
            .filename = filename,
        };
    }

    pub fn printUsage(version: std.SemanticVersion) void {
        std.debug.print(command_help, .{ version.major, version.minor, version.patch });
    }
};
