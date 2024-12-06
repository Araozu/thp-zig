const std = @import("std");
const lexic = @import("lexic");
const syntax = @import("syntax");

const thp_version: []const u8 = "0.0.1";

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

    const tokens = try lexic.tokenize(line, alloc);
    defer tokens.deinit();

    try bw.flush();
}
