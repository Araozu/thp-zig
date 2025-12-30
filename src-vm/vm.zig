const std = @import("std");
const config = @import("config");
const m_chunk = @import("./chunk.zig");
const m_value = @import("./value.zig");
const m_obj = @import("./obj.zig");
const m_debug = @import("./debug.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;
const Value = m_value.Value;

const STACK_MAX = 1024;

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
        self.*.stack_top += chunk.var_slots;
    }

    pub fn interpret(self: *Self) InterpretResult {
        return self.run();
    }

    fn run(self: *Self) InterpretResult {
        // Setup the slots for variables
        for (0..self.chunk.var_slots) |_| {
            self.stack_top += 1;
        }

        while (true) {
            if (config.tracing) {
                std.debug.print("          ", .{});
                var start_ptr: [*]Value = &self.stack;
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
                .OP_PRINT => {
                    const value = self.pop();
                    const obj = switch (value) {
                        .ref => |ref| ref,
                        .value => @panic("Expected to find a reference on the stack, found a value. This is a bug in the compiler."),
                    };

                    const obj_string: *m_obj.ObjString = switch (obj.t) {
                        .String => @alignCast(@fieldParentPtr("base", obj)),
                    };
                    switch (obj_string.bytes) {
                        .constant => |bytes| {
                            std.debug.print("{s}\n", .{bytes});
                        },
                        .heap => |bytes| {
                            std.debug.print("{s}\n", .{bytes});
                        },
                    }
                },
                .OP_CONSTANT => {
                    const constant = self.read_constant();
                    self.push(.{ .value = constant });
                },

                //
                .OP_ADD_I64 => {
                    const b = self.pop_n(i64);
                    const a = self.pop_n(i64);
                    self.push(.{ .value = @bitCast(a + b) });
                },
                .OP_SUB_I64 => {
                    const b = self.pop_n(i64);
                    const a = self.pop_n(i64);
                    self.push(.{ .value = @bitCast(a - b) });
                },
                .OP_NEGATE_I64 => self.push(.{ .value = @bitCast(-self.pop_n(i64)) }),
                //
                .OP_ADD_F64 => {
                    const b = self.pop_n(f64);
                    const a = self.pop_n(f64);
                    self.push(.{ .value = @bitCast(a + b) });
                },
                .OP_SUB_F64 => {
                    const b = self.pop_n(f64);
                    const a = self.pop_n(f64);
                    self.push(.{ .value = @bitCast(a - b) });
                },
                .OP_NEGATE_F64 => self.push(.{ .value = @bitCast(-self.pop_n(f64)) }),
                //
                .OP_ADD_U64 => {
                    const b = self.pop_n(u64);
                    const a = self.pop_n(u64);
                    self.push(.{ .value = @bitCast(a + b) });
                },
                .OP_SUB_U64 => {
                    const b = self.pop_n(u64);
                    const a = self.pop_n(u64);
                    self.push(.{ .value = @bitCast(a - b) });
                },
                //
                .OP_CONCAT => {
                    //
                    // pop two strings from the stack
                    //
                    const obj_string_1: *m_obj.ObjString = switch (self.pop()) {
                        .ref => |ref| switch (ref.t) {
                            .String => @alignCast(@fieldParentPtr("base", ref)),
                        },
                        .value => @panic("Expected to find a reference on the stack, found a value. This is a bug in the compiler."),
                    };
                    const obj_string_2: *m_obj.ObjString = switch (self.pop()) {
                        .ref => |ref| switch (ref.t) {
                            .String => @alignCast(@fieldParentPtr("base", ref)),
                        },
                        .value => @panic("Expected to find a reference on the stack, found a value. This is a bug in the compiler."),
                    };

                    const bytes_1: []const u8 = switch (obj_string_1.bytes) {
                        .constant => |b| b,
                        .heap => |b| b,
                    };
                    const bytes_2: []const u8 = switch (obj_string_2.bytes) {
                        .constant => |b| b,
                        .heap => |b| b,
                    };

                    //
                    // concatenate them
                    //
                    const new_str_pointer: u64 = self.chunk.create_string_2(bytes_2, bytes_1) catch {
                        std.debug.print("Runtime Error: Unable to concatenate strings due to memory allocation failure.\n", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };

                    // push the result back onto the stack
                    self.push(.{ .ref = @ptrFromInt(@as(usize, @intCast(new_str_pointer))) });
                },
                .OP_REF => {
                    // Reads the constant at `constant_idx`.
                    const obj_pointer: usize = @intCast(self.read_constant());

                    // Interprets it as a pointer to an Obj.
                    const obj_ptr: *m_obj.Obj = @ptrFromInt(obj_pointer);

                    // Pushes the Obj onto the stack, as a Value.
                    self.push(.{ .ref = obj_ptr });
                },
                .OP_F64_TO_STRING => {
                    const value: f64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    const value_bytes = std.fmt.allocPrint(self.chunk.allocator, "{d}", .{value}) catch {
                        std.debug.print("Runtime Error: Unable to convert f64 to string due to memory allocation failure.\n", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    defer self.chunk.allocator.free(value_bytes);

                    // Build the string representation
                    const new_str_pointer: u64 = self.chunk.create_string(value_bytes) catch {
                        std.debug.print("Runtime Error: Unable to convert f64 to string due to memory allocation failure.\n", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    self.push(.{ .ref = @ptrFromInt(@as(usize, @intCast(new_str_pointer))) });
                },
                .OP_U64_TO_STRING => {
                    const value: u64 = switch (self.pop()) {
                        .value => |v| @bitCast(v),
                        .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
                    };

                    const value_bytes = std.fmt.allocPrint(self.chunk.allocator, "{d}", .{value}) catch {
                        std.debug.print("Runtime Error: Unable to convert f64 to string due to memory allocation failure.\n", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    defer self.chunk.allocator.free(value_bytes);

                    // Build the string representation
                    const new_str_pointer: u64 = self.chunk.create_string(value_bytes) catch {
                        std.debug.print("Runtime Error: Unable to convert f64 to string due to memory allocation failure.\n", .{});
                        return .INTERPRET_RUNTIME_ERROR;
                    };
                    self.push(.{ .ref = @ptrFromInt(@as(usize, @intCast(new_str_pointer))) });
                },
                .OP_STORE => {
                    const slot_idx: u8 = self.read_byte();
                    const value = self.pop();
                    self.stack[slot_idx] = value;
                },
                .OP_LOAD => {
                    const slot_idx: u8 = self.read_byte();
                    const value = self.stack[slot_idx];
                    self.push(value);
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

    /// Pops a number from the stack, and panics if it's a reference instead
    fn pop_n(self: *Self, comptime T: type) T {
        self.stack_top -= 1;
        const value = self.stack_top[0];
        return switch (value) {
            .value => |v| @bitCast(v),
            .ref => @panic("Expected to find a f64 on the stack, found a reference. This is a bug in the compiler."),
        };
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
