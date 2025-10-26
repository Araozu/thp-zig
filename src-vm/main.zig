const std = @import("std");
const m_chunk = @import("./chunk.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};

    var chunk: Chunk = undefined;
    chunk.init(gpa.allocator());
    defer chunk.deinit();

    try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN));
    m_chunk.dissasemble_chunk(&chunk, "test chunk");
}
