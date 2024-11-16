const std = @import("std");
const lexic = @import("./01_lexic/root.zig");

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
    try stdout.print("Enter expressions to evaluate. Enter CTRL-D to exit.\n\n", .{});
    try bw.flush();

    const stdin = std.io.getStdIn().reader();

    try stdout.print("thp => ", .{});
    try bw.flush();

    const user_input = try stdin.readUntilDelimiterAlloc(std.heap.page_allocator, '\n', 8192);
    defer std.heap.page_allocator.free(user_input);

    try stdout.print("got: `{s}`\n", .{user_input});
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "new test" {
    const res = lexic.stub();
    try std.testing.expectEqual(@as(i32, 322), res);
}
