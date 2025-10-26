const std = @import("std");
const m_value = @import("./value.zig");

const Value = m_value.Value;

pub const OpCode = enum {
    OP_CONSTANT,
    OP_RETURN,
};

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    constants: std.ArrayListUnmanaged(Value),

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
            .constants = .empty,
        };
    }

    pub fn write_chunk(self: *Self, byte: u8) !void {
        try self.code.append(self.allocator, byte);
    }

    pub fn write_constant(self: *Self, constant: Value) !usize {
        try self.constants.append(self.allocator, constant);
        return self.constants.items.len - 1;
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.constants.deinit(self.allocator);
    }
};
