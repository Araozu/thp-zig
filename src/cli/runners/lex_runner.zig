const std = @import("std");
const config = @import("config");

const CompileOptions = @import("../compile_command.zig").CompileOptions;

/// Runs the `lex` command
pub fn run() !void {
    //
    if (!config.json) {
        std.debug.print("JSON output not enabled, compile thp with the `-Djson` flag\n", .{});
    }
}
