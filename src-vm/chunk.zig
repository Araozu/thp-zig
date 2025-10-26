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
