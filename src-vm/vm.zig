const std = @import("std");
const config = @import("config");
const m_chunk = @import("./chunk.zig");
const m_value = @import("./value.zig");
const m_debug = @import("./debug.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;
const Value = m_value.Value;

const STACK_MAX = 256;

pub const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: Chunk,
    ip: [*]u8,
    stack: [STACK_MAX]Value,
    stack_top: [*]Value,

    const Self = @This();

    pub fn init(self: *Self, chunk: Chunk) void {
        self.* = .{
            .chunk = chunk,
            .ip = chunk.code.items.ptr,
            .stack = undefined,
            .stack_top = undefined,
        };
        self.*.stack_top = &self.*.stack;
    }

    pub fn interpret(self: *Self) InterpretResult {
        return self.run();
    }

    fn run(self: *Self) InterpretResult {
        while (true) {
            // if (config.tracing) {
            //     std.debug.print("          ", .{});
            //     var start_ptr: [*]u64 = &self.stack;
            //     while (start_ptr != self.stack_top) {
            //         std.debug.print("[ ", .{});
            //         m_value.print_value(start_ptr[0]);
            //         std.debug.print(" ]", .{});
            //
            //         start_ptr += 1;
            //     }
            //     std.debug.print("\n", .{});
            //     _ = m_debug.dissasemble_instruction(&self.chunk, self.ip - self.chunk.code.items.ptr);
            // }

            const e_instruction: OpCode = @enumFromInt(self.read_byte());
            switch (e_instruction) {
                .OP_RETURN => {
                    return .INTERPRET_OK;
                },
                .OP_PRINT_F64 => {
                    switch (self.pop()) {
                        .value => |value| {
                            std.debug.print("{d}\n", .{@as(f64, @bitCast(value))});
                        },
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    }
                },
                .OP_PRINT_CONST => {
                    @panic("Regression: OP_PRINT_CONST");
                },
                .OP_CONSTANT => {
                    const constant = self.read_constant();
                    self.push(.{ .value = constant });
                },
                .OP_NEGATE_F64 => {
                    switch (self.pop()) {
                        .value => |value| {
                            self.push(.{ .value = @bitCast(-@as(f64, @bitCast(value))) });
                        },
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    }
                },
                .OP_ADD_F64 => {
                    const b: f64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };
                    const a: f64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    self.push(.{ .value = @bitCast(a + b) });
                },
                .OP_SUB_F64 => {
                    const b: f64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };
                    const a: f64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    self.push(.{ .value = @bitCast(a - b) });
                },
                .OP_ADD_U64 => {
                    const b: u64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };
                    const a: u64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    self.push(.{ .value = @bitCast(a + b) });
                },
                .OP_SUB_U64 => {
                    const b: u64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };
                    const a: u64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    self.push(.{ .value = @bitCast(a - b) });
                },
                .OP_CONCAT => unreachable,
            }
        }
    }

    fn push(self: *Self, value: Value) void {
        self.stack_top[0] = value;
        self.stack_top += 1;
    }

    fn pop(self: *Self) Value {
        self.stack_top -= 1;
        return self.stack_top[0];
    }

    // NOTE: crafting interpreters had this as a C macro
    /// Read a single byte from the chunk's bytecode array
    fn read_byte(self: *Self) u8 {
        const b = self.ip[0];
        self.ip += 1;
        return b;
    }

    // NOTE: crafting interpreters had this as a C macro
    /// Read a constant from the chunk's constant array
    fn read_constant(self: *Self) u64 {
        return self.chunk.constants.items[self.read_byte()];
    }

    /// Read raw bytes from the chunk's raw byte array.
    fn read_constant_bytes(self: *Self, offset: usize, len: usize) []u8 {
        std.debug.assert(offset + len <= self.chunk.raw_bytes.items.len);

        return self.chunk.raw_bytes.items[offset..][0..len];
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
