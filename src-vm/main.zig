const std = @import("std");

const Chunk = @import("./chunk.zig").Chunk;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};

    var chunk: Chunk = undefined;
    chunk.init(gpa.allocator());
    defer chunk.deinit();

    std.debug.print("hello\n", .{});
}
