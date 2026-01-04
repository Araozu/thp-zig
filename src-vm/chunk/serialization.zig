const std = @import("std");

const m_chunk = @import("./root.zig");

const Chunk = m_chunk.Chunk;

/// Serializes a Chunk into a propietary binary format.
pub fn serialize(chunk: *const Chunk, writer: *std.Io.Writer) !void {
    _ = try writer.write("THP!");

    //  constants
    _ = try writer.writeInt(u32, @intCast(chunk.constants.items.len), .big);
    for (chunk.constants.items) |bytes| {
        _ = try writer.writeInt(u64, @bitCast(bytes), .big);
    }

    //  raw bytes
    _ = try writer.writeInt(u32, @intCast(chunk.raw_bytes.items.len), .big);
    for (chunk.raw_bytes.items) |byte| {
        _ = try writer.writeInt(u8, @bitCast(byte), .big);
    }
    _ = try writer.write(std.mem.sliceAsBytes(chunk.code.items));

    // don't forget to flush
    try writer.flush();
}

/// Deserialized a chunk from the propietary format
pub fn deserialize(reader: std.Io.Reader) !Chunk {
    //
    _ = reader;
}
