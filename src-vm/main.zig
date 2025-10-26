const std = @import("std");
const m_chunk = @import("./chunk.zig");
const m_debug = @import("./debug.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};

    var chunk: Chunk = undefined;
    chunk.init(gpa.allocator());
    defer chunk.deinit();

    try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN));
    const constant_idx = try chunk.write_constant(1.2);
    try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT));
    try chunk.write_chunk(@intCast(constant_idx));

    m_debug.dissasemble_chunk(&chunk, "test chunk");
}
