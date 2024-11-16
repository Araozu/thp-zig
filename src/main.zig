const std = @import("std");
const thp_version: []const u8 = "0.0.0";

pub fn main() !void {
    try repl();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}

fn repl() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("The THP REPL, v{s}\n", .{thp_version});
    try stdout.print("Enter expressions to evaluate. Enter CTRL-D to exit.\n", .{});

    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
