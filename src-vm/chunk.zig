const std = @import("std");
const m_value = @import("./value.zig");

const Value = m_value.Value;

pub const OpCode = enum(u8) {
    OP_RETURN = 0x00,
    OP_PRINT = 0x01,
    OP_CONSTANT = 0x02,
    OP_ADD = 0x03,
    OP_NEGATE = 0x04,
};

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,
    constants: std.ArrayListUnmanaged(Value),
    lines: std.ArrayListUnmanaged(u32),

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
            .constants = .empty,
            .lines = .empty,
        };
    }

    // HACK: input raw bytes without support for line numbers
    pub fn write_raw_bytecode_bytes(self: *Self, bytes: []u8, line: u32) !void {
        try self.code.appendSlice(self.allocator, bytes);
        try self.lines.appendNTimes(self.allocator, line, bytes.len);
    }

    pub fn write_chunk(self: *Self, byte: u8, line: u32) !void {
        try self.code.append(self.allocator, byte);
        try self.lines.append(self.allocator, line);
    }

    pub fn write_constant(self: *Self, constant: Value) !usize {
        try self.constants.append(self.allocator, constant);
        return self.constants.items.len - 1;
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.lines.deinit(self.allocator);
    }
};
