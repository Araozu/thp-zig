const std = @import("std");

pub const OpCode = enum(u8) {
    OP_RETURN = 0x00,
    OP_PRINT_F64 = 0x01,

    /// Push a constant onto the stack. Its always a u64.
    OP_CONSTANT = 0x02,

    /// Binary addition
    ///
    /// Pops two values from the stack, adds them, and pushes the result.
    OP_ADD_F64 = 0x03,
    OP_NEGATE_F64 = 0x04,
    /// Pops two values from the stack, substracts them, and pushes the result.
    OP_SUB_F64 = 0x05,

    //
    //  u64 opcodes
    //
    OP_ADD_U64 = 0x07,
    OP_SUB_U64 = 0x08,
};

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    // Scalar constants all aligned to u64
    constants: std.ArrayListUnmanaged(u64),

    // Raw bytes, used for string constants
    raw_bytes: std.ArrayListUnmanaged(u8),
    lines: std.ArrayListUnmanaged(u32),

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
            .constants = .empty,
            .raw_bytes = .empty,
            .lines = .empty,
        };
    }

    // HACK: input raw bytes without support for line numbers
    pub fn write_raw_bytecode_bytes(self: *Self, bytes: []u8, line: u32) !void {
        try self.code.appendSlice(self.allocator, bytes);
        try self.lines.appendNTimes(self.allocator, line, bytes.len);
    }

    /// Write a single byte to the chunk's code array, along with its line number
    pub fn write_chunk(self: *Self, byte: u8, line: u32) !void {
        try self.code.append(self.allocator, byte);
        try self.lines.append(self.allocator, line);
    }

    /// Write a constant to the chunk's constant array, returning its index
    pub fn write_constant(self: *Self, constant: u64) !usize {
        try self.constants.append(self.allocator, constant);
        return self.constants.items.len - 1;
    }

    /// Write raw bytes to the chunk's raw byte array, returning the start index
    pub fn write_constant_bytes(self: *Self, bytes: []u8) !usize {
        const start_index = self.raw_bytes.items.len;
        try self.raw_bytes.appendSlice(self.allocator, bytes);
        return start_index;
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.raw_bytes.deinit(self.allocator);
        self.lines.deinit(self.allocator);
    }
};
