const std = @import("std");
const lexic = @import("./01_lexic/root.zig");

const thp_version: []const u8 = "0.0.0";

pub fn main() !void {
    try repl();
}

fn repl() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("The THP REPL, v{s}\n", .{thp_version});
    try stdout.print("Enter expressions to evaluate. Enter CTRL-D to exit.\n", .{});
    try bw.flush();

    const stdin = std.io.getStdIn().reader();

    try stdout.print("\nthp => ", .{});
    try bw.flush();

    const bare_line = try stdin.readUntilDelimiterAlloc(std.heap.page_allocator, '\n', 8192);
    defer std.heap.page_allocator.free(bare_line);
    const line = std.mem.trim(u8, bare_line, "\r");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    try lexic.tokenize(line, alloc);

    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
