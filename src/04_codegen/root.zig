const std = @import("std");
const m_syntax = @import("syntax");
const m_vm = @import("vm");

const Chunk = m_vm.Chunk;
const OpCode = m_vm.OpCode;
const ASTModule = m_syntax.Module;

pub const ByteCodeGenerator = struct {
    ast: *const ASTModule,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(self: *Self, ast: *const ASTModule, alloc: std.mem.Allocator) void {
        self.* = .{
            .ast = ast,
            .allocator = alloc,
        };
    }

    /// Caller must call `deinit` on the returned chunk
    pub fn emit(self: *Self) !Chunk {
        var chunk: Chunk = undefined;
        chunk.init(self.allocator);
        errdefer chunk.deinit();

        // walk the AST, generate bytecode
        for (self.ast.statements.items) |*statement| {
            switch (statement.*) {
                .variableBinding => |b| {
                    // ignore the binding itself, focus on the expresion
                    try emit_pratt_expression(&chunk, &b.expression);
                },
                .expression => |e| {
                    try emit_pratt_expression(&chunk, e);
                },
            }
        }

        try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 0);

        return chunk;
    }

    /// What does this do? it computes the bytecode for an expression,
    /// and has the top of the stack ready to use that computed value
    fn emit_pratt_expression(chunk: *Chunk, exp: *m_syntax.PrattExpression) !void {
        switch (exp.*) {
            .function => |*f| {
                // Emit bytecode for the args
                for (f.arguments.items) |argument| {
                    try emit_pratt_expression(chunk, argument);
                }

                // call the function, if `print`
                switch (f.callee.*) {
                    .primary => |primary| {
                        switch (primary.*) {
                            .identifier => |id| {
                                if (!std.mem.eql(u8, id.value, "print")) {
                                    std.debug.panic("Not implemented: function call other than print\n", .{});
                                }

                                try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT_F64), 1);
                            },
                            else => std.debug.panic("Not implemented: not identifier function call\n", .{}),
                        }
                        return;
                    },
                    else => std.debug.panic("Not implemented: function call\n", .{}),
                }
            },
            .primary => |p| try emit_primary_expresion(chunk, p),
            .binary => |*binary| {
                // HACK: hardcoded binary operators

                // emit for left and right
                try emit_pratt_expression(chunk, binary.left);
                try emit_pratt_expression(chunk, binary.right);

                // emit add opcode
                if (std.mem.eql(u8, binary.operator.value, "+")) {
                    try chunk.write_chunk(@intFromEnum(OpCode.OP_ADD_F64), 123);
                } else if (std.mem.eql(u8, binary.operator.value, "-")) {
                    try chunk.write_chunk(@intFromEnum(OpCode.OP_SUB_F64), 123);
                } else {
                    std.debug.panic("Not implemented: operator `{s}`\n", .{binary.operator.value});
                }
            },
        }
    }

    fn emit_primary_expresion(chunk: *Chunk, exp: *m_syntax.PrimaryExpression) !void {
        switch (exp.*) {
            .float => |t_float| {
                // put the float at the top of the stack
                const float_value = try std.fmt.parseFloat(f64, t_float.value);

                // Add to the constants section
                const constant_idx = try chunk.write_constant(@bitCast(float_value));
                // Push to stack
                try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT_F64), 1);
                try chunk.write_chunk(@intCast(constant_idx), 123);
            },
            else => {
                // TODO
                std.debug.panic("Not implemented: bytecode from function call\n", .{});
            },
        }
    }

    pub fn deinit() void {
        //
    }
};
