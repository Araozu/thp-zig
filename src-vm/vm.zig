const std = @import("std");
const config = @import("config");
const m_chunk = @import("./chunk.zig");
const m_value = @import("./value.zig");
const m_debug = @import("./debug.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;

const STACK_MAX = 256;

pub const InterpretResult = enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: Chunk,
    ip: [*]u8,
    stack: [STACK_MAX]u64,
    stack_top: [*]u64,

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
            if (config.tracing) {
                std.debug.print("          ", .{});
                var start_ptr: [*]u64 = &self.stack;
                while (start_ptr != self.stack_top) {
                    std.debug.print("[ ", .{});
                    m_value.print_value(start_ptr[0]);
                    std.debug.print(" ]", .{});

                    start_ptr += 1;
                }
                std.debug.print("\n", .{});
                _ = m_debug.dissasemble_instruction(&self.chunk, self.ip - self.chunk.code.items.ptr);
            }

            const e_instruction: OpCode = @enumFromInt(self.read_byte());
            switch (e_instruction) {
                .OP_RETURN => {
                    return .INTERPRET_OK;
                },
                .OP_CONSTANT_F64 => {
                    const constant = self.read_constant_f64();
                    self.push_f64(constant);
                },
                .OP_PRINT_F64 => {
                    std.debug.print("{d}\n", .{self.pop_f64()});
                },
                .OP_NEGATE_F64 => self.push_f64(-self.pop_f64()),
                .OP_ADD_F64 => {
                    const b = self.pop_f64();
                    const a = self.pop_f64();
                    self.push_f64(a + b);
                },
                .OP_SUB_F64 => {
                    const b = self.pop_f64();
                    const a = self.pop_f64();
                    self.push_f64(a - b);
                },
            }
        }
    }

    fn push_f64(self: *Self, value: f64) void {
        self.stack_top[0] = @bitCast(value);
        self.stack_top += 1;
    }

    fn pop_f64(self: *Self) f64 {
        self.stack_top -= 1;
        return @bitCast(self.stack_top[0]);
    }

    // NOTE: crafting interpreters had this as a C macro
    fn read_byte(self: *Self) u8 {
        const b = self.ip[0];
        self.ip += 1;
        return b;
    }

    // NOTE: crafting interpreters had this as a C macro
    fn read_constant_f64(self: *Self) f64 {
        return @bitCast(self.chunk.constants.items[self.read_byte()]);
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
