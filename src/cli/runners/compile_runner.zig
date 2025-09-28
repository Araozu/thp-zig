const std = @import("std");

const CompileOptions = @import("../compile_command.zig").CompileOptions;

/// Runs the compile command.
pub fn run(self: *const CompileOptions) !void {
    // Read file

    var filebuffer: [4096]u8 = undefined;
    const absolute_path = try std.fs.realpath(self.filename, &filebuffer);

    const source_file = try std.fs.createFileAbsolute(absolute_path, std.fs.File.CreateFlags{
        .read = true,
        .truncate = false,
    });

    // 20MB max buffer
    var buf: [1024 * 1024 * 20]u8 = undefined;
    const bytes_read = try source_file.read(&buf);

    std.debug.print("Read {d} bytes from {s}\n", .{ bytes_read, self.filename });

    std.debug.print("file:\n\n{s}\n", .{buf[0..]});

    // Lex
    // Parse
    // Analyze
    // Emit
    // Out
}
