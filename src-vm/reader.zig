const std = @import("std");
const m_chunk = @import("./chunk.zig");

pub fn read_bytecode(allocator: std.mem.Allocator, bytes: []u8) !m_chunk.Chunk {
    // Bytecode must be at least 6 bytes long: 4 bytes header, 1 byte constant length (0), 1 byte OP_RETURN
    if (bytes.len < 6) {
        std.debug.print("Invalid bytecode: THP bytecode is at least 6 bytes long\n", .{});
        return error.Invalid;
    }

    // Assert first 4 bytes have the right signature

    if (!std.mem.eql(u8, bytes[0..4], "THP!")) {
        const bytes_hex = std.fmt.bytesToHex(bytes[0..4], std.fmt.Case.lower);
        std.debug.print("Invalid bytecode header bytes: {s}\n", .{bytes_hex});
        return error.Invalid;
    }

    // Build chunk
    var chunk: m_chunk.Chunk = undefined;
    chunk.init(allocator);
    errdefer chunk.deinit();

    // Read next byte for size
    const contants_bytes_len = bytes[4];

    // Read constant bytes
    if (contants_bytes_len > 0) {
        // Ensure enough bytes
        try chunk.constants.ensureTotalCapacity(chunk.allocator, contants_bytes_len);

        // Read bytes
        const constants_slice = bytes[5..(5 + contants_bytes_len)];

        const f64_ptr: [*]f64 = @ptrCast(@alignCast(constants_slice.ptr));
        const f64_count = bytes.len / @sizeOf(f64);
        const constants_bytes = f64_ptr[0..f64_count];

        try chunk.constants.appendSlice(chunk.allocator, constants_bytes);
    }

    // Remaining bytes are bytecode
    const bytecode_bytes = bytes[5 + contants_bytes_len ..];

    // Write bytecode bytes
    try chunk.write_raw_bytecode_bytes(bytecode_bytes, 1);

    return chunk;
}
