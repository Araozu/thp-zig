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
    const contants_bytes_len = std.mem.readInt(u32, bytes[4..8], .big);

    //
    // Read constant bytes
    //
    if (contants_bytes_len > 0) {
        // Ensure enough bytes
        try chunk.constants.ensureTotalCapacity(chunk.allocator, contants_bytes_len);

        // Read & insert bytes
        for (0..contants_bytes_len) |i| {
            const bytes_start = 8 + (i * 8);
            const bytes_end = 8 + ((i + 1) * 8);
            const u64_value = std.mem.readInt(u64, bytes[bytes_start..bytes_end][0..8], .big);

            try chunk.constants.append(chunk.allocator, u64_value);
        }
    }

    const next_pos = 8 + (contants_bytes_len * 8);
    const raw_bytes_len = std.mem.readInt(u32, bytes[next_pos..][0..4], .big);

    //
    // Read raw bytes
    //
    if (raw_bytes_len > 0) {
        // Ensure enough bytes
        try chunk.raw_bytes.ensureTotalCapacity(chunk.allocator, raw_bytes_len);

        // Read & insert bytes
        try chunk.raw_bytes.appendSlice(
            chunk.allocator,
            bytes[(next_pos + 4)..(next_pos + 4 + raw_bytes_len)],
        );
    }

    // Remaining bytes are bytecode
    const bytecode_start_idx = 8 + (contants_bytes_len * 8);
    const bytecode_bytes = bytes[bytecode_start_idx..];

    // Write bytecode bytes
    try chunk.write_raw_bytecode_bytes(bytecode_bytes, 1);

    return chunk;
}
