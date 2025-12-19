const std = @import("std");
const tracing = @import("config").tracing;

const m_obj = @import("./obj.zig");

const Obj = m_obj.Obj;

pub const OpCode = enum(u8) {
    OP_RETURN = 0x00,
    /// Deprecated
    OP_PRINT_F64 = 0x01,

    /// <cons> idx
    ///
    /// Push a constant **index** onto the stack. Its always a u64.
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

    /// Prints the string currently at the top of the stack
    OP_PRINT_CONST = 0x09,

    /// String concatenation
    OP_CONCAT = 0x0A,

    /// <ref> constant_idx:u8
    ///
    /// Reads the constant at `constant_idx`.
    /// Interprets it as a pointer to an Obj.
    /// Pushes the Obj onto the stack, as a Value.
    OP_REF = 0x0B,
};

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    // Scalar constants all aligned to u64
    constants: std.ArrayListUnmanaged(u64),

    // Raw bytes, used for string constants
    raw_bytes: std.ArrayListUnmanaged(u8),
    lines: std.ArrayListUnmanaged(u32),

    refs: std.ArrayListUnmanaged(*Obj),

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
            .constants = .empty,
            .raw_bytes = .empty,
            .lines = .empty,
            .refs = .empty,
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
    pub fn write_constant_bytes(self: *Self, bytes: []const u8) !usize {
        const start_index = self.raw_bytes.items.len;
        try self.raw_bytes.appendSlice(self.allocator, bytes);
        return start_index;
    }

    /// Creates a constant string Obj and returns a pointer to it as `u64`.
    /// Clones the bytes.
    pub fn create_string(self: *Self, bytes: []const u8) !u64 {
        const obj_string = try self.allocator.create(m_obj.ObjString);
        errdefer self.allocator.destroy(obj_string);

        try obj_string.init_dynamic(self.allocator, bytes);

        if (tracing) {
            const obj: *m_obj.Obj = &obj_string.base;

            std.debug.print(
                \\Creating string object for `{s}`:
                \\    obj_string at address 0x{X}
                \\    obj        at address 0x{X}
                \\
            ,
                .{ bytes, @intFromPtr(obj_string), @intFromPtr(obj) },
            );
        }

        // Store the reference
        try self.refs.append(self.allocator, &obj_string.base);

        return @intCast(@intFromPtr(&obj_string.base));
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.raw_bytes.deinit(self.allocator);
        self.lines.deinit(self.allocator);

        // Delete string refs
        for (self.refs.items) |reference| {
            switch (reference.t) {
                .String => {
                    const str_obj: *m_obj.ObjString = @alignCast(@fieldParentPtr("base", reference));
                    str_obj.deinit(self.allocator);
                },
            }
        }

        self.refs.deinit(self.allocator);
    }
};
