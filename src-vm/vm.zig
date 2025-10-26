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
            if (config.tracing) {
                _ = m_debug.dissasemble_instruction(&self.chunk, self.ip - self.chunk.code.items.ptr);
            }

            const e_instruction: OpCode = @enumFromInt(self.read_byte());
            switch (e_instruction) {
                .OP_RETURN => {
                    return .INTERPRET_OK;
                },
                .OP_CONSTANT => {
                    const constant = self.read_constant();

                    m_value.print_value(constant);
                    std.debug.print("\n", .{});
                    // break;
                },
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
    fn read_byte(self: *Self) u8 {
        const b = self.ip[0];
        self.ip += 1;
        return b;
    }

    // NOTE: crafting interpreters had this as a C macro
    fn read_constant(self: *Self) m_value.Value {
        return self.chunk.constants.items[self.read_byte()];
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
