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
                .OP_PRINT_F64 => {
                    std.debug.print("{d}\n", .{@as(f64, @bitCast(self.pop()))});
                },
                .OP_CONSTANT => {
                    const constant = self.read_constant();
                    self.push(constant);
                },
                .OP_NEGATE_F64 => {
                    const v: f64 = @bitCast(self.pop());
                    self.push(@bitCast(-v));
                },
                .OP_ADD_F64 => {
                    const b: f64 = @bitCast(self.pop());
                    const a: f64 = @bitCast(self.pop());
                    self.push(@bitCast(a + b));
                },
                .OP_SUB_F64 => {
                    const b: f64 = @bitCast(self.pop());
                    const a: f64 = @bitCast(self.pop());
                    self.push(@bitCast(a - b));
                },
                .OP_ADD_U64 => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(a + b);
                },
                .OP_SUB_U64 => {
                    const b = self.pop();
                    const a = self.pop();
                    self.push(a - b);
                },
            }
        }
    }

    fn push(self: *Self, value: u64) void {
        self.stack_top[0] = value;
        self.stack_top += 1;
    }

    fn pop(self: *Self) u64 {
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
    fn read_constant(self: *Self) u64 {
        return self.chunk.constants.items[self.read_byte()];
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};
