const std = @import("std");

pub const OpCode = enum {
    OP_RETURN,
};

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
        };
    }

    pub fn write_chunk(self: *Self, byte: u8) !void {
        try self.code.append(self.allocator, byte);
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
    }
};

pub fn dissasemble_chunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    const len = chunk.code.items.len;
    var pos: usize = 0;
    while (pos < len) {
        pos = dissasemble_instruction(chunk, pos);
    }
}

fn dissasemble_instruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("{d:0<4} ", .{offset});

    const instruction = chunk.code.items[offset];
    const e_instruction: OpCode = @enumFromInt(instruction);
    switch (e_instruction) {
        .OP_RETURN => |t| {
            return simple_instruction(@tagName(t), offset);
        },
    }

    return 0;
}

fn simple_instruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}
