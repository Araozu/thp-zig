const std = @import("std");
const m_chunk = @import("./chunk.zig");
const m_debug = @import("./debug.zig");
const m_vm = @import("./vm.zig");

pub const Chunk = m_chunk.Chunk;
pub const OpCode = m_chunk.OpCode;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};

    // ========================================
    //  Hand build a chunk
    // ========================================
    var chunk: Chunk = undefined;
    chunk.init(gpa.allocator());
    defer chunk.deinit();

    {
        const constant_idx = try chunk.write_constant(1.2);
        try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 123);
        try chunk.write_chunk(@intCast(constant_idx), 123);
    }
    {
        const constant_idx = try chunk.write_constant(4.8);
        try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 123);
        try chunk.write_chunk(@intCast(constant_idx), 123);
    }
    {
        try chunk.write_chunk(@intFromEnum(OpCode.OP_ADD), 123);
    }

    try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT), 123);
    try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 123);

    // m_debug.dissasemble_chunk(&chunk, "test chunk");
    // std.debug.print("== end chunk assembly ==\n\n", .{});

    // ========================================
    //  Create & run the VM
    // ========================================

    var vm: m_vm.VM = undefined;
    vm.init(chunk);
    defer vm.deinit();

    _ = vm.interpret();
}
