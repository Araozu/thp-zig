const std = @import("std");
const tracing = @import("config").tracing;

const m_obj = @import("./obj.zig");

pub const OpCode = @import("./opcode.zig").OpCode;
const Obj = m_obj.Obj;

pub const Chunk = struct {
    code: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    // Scalar constants all aligned to u64
    constants: std.ArrayListUnmanaged(u64),

    // Raw bytes, used for string constants
    raw_bytes: std.ArrayListUnmanaged(u8),
    lines: std.ArrayListUnmanaged(u32),

    // Pointers to dynamically allocated objects
    refs: std.ArrayListUnmanaged(*Obj),

    // Number of variables slots used by this chunk
    var_slots: u8,

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator, var_slots: u8) void {
        self.* = .{
            .code = .empty,
            .allocator = allocator,
            .constants = .empty,
            .raw_bytes = .empty,
            .lines = .empty,
            .refs = .empty,
            .var_slots = var_slots,
        };
    }

    // HACK: input raw bytes
    pub fn write_raw_bytecode_bytes(self: *Self, bytes: []u8, line: u32) !void {
        try self.code.appendSlice(self.allocator, bytes);
        try self.lines.appendNTimes(self.allocator, line, bytes.len);
    }

    /// Write a single byte to the chunk's code array, along with its line number
    pub fn write_chunk(self: *Self, byte: u8, line: u32) !void {
        try self.code.append(self.allocator, byte);
        try self.lines.append(self.allocator, line);
    }

    /// Writes a single opcode. The opcode enum is casted to a byte.
    pub fn write_opcode(self: *Self, opcode: OpCode, line: u32) !void {
        try self.write_chunk(@intFromEnum(opcode), line);
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

    /// Creates a constant string Obj and returns a pointer to it as `u64`,
    /// from 2 slices. Used for concatenation.
    ///
    /// Clones the bytes.
    ///
    /// Returns the pointer to the Obj as u64.
    pub fn create_string_2(self: *Self, bytes_1: []const u8, bytes_2: []const u8) !u64 {
        const obj_string = try self.allocator.create(m_obj.ObjString);
        errdefer self.allocator.destroy(obj_string);

        try obj_string.init_dynamic_from_2(self.allocator, bytes_1, bytes_2);

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
                    self.allocator.destroy(str_obj);
                },
            }
        }

        self.refs.deinit(self.allocator);
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "should cleanup 1" {
    const allocator = std.testing.allocator;
    const chunk = try allocator.create(Chunk);
    defer allocator.destroy(chunk);

    chunk.init(allocator, 0);
    defer chunk.deinit();
}

test "should write to a chunk" {
    var chunk: Chunk = undefined;
    chunk.init(std.testing.allocator, 0);
    defer chunk.deinit();

    try chunk.write_chunk(0x00, 1);
    try expectEqual(0x00, chunk.code.items[0]);

    const pos = try chunk.write_constant(0xFF);
    try expectEqual(0, pos);
    try expectEqual(0xFF, chunk.constants.items[0]);
}

test "should create a const string" {
    var chunk: Chunk = undefined;
    chunk.init(std.testing.allocator, 0);
    defer chunk.deinit();

    _ = try chunk.create_string("hello");
    _ = try chunk.create_string("world");
}

test "should create a const string from 2 strings" {
    var chunk: Chunk = undefined;
    chunk.init(std.testing.allocator, 0);
    defer chunk.deinit();

    _ = try chunk.create_string_2("hello ", "world");
}
