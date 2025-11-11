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

        // walk the AST, generate bytecode?

        for (self.ast.statements.items) |*statement| {
            switch (statement.*) {
                .variableBinding => |b| {
                    // ignore the binding itself, focus on the expresion
                    try emit_call_expression(&chunk, &b.expression);
                },
                .expression => |e| {
                    try emit_call_expression(&chunk, e);
                },
            }
        }

        try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 0);

        return chunk;
    }

    /// What does this do? it computes the bytecode for an expression,
    /// and has the top of the stack ready to use that computed value
    fn emit_call_expression(chunk: *Chunk, exp: *m_syntax.PrattExpression) !void {
        switch (exp.*) {
            .function => |*f| {
                // TODO

                // Emit bytecode for the args
                for (f.arguments.items) |argument| {
                    try emit_call_expression(chunk, argument);
                }

                // call the function, if `print`
                switch (f.callee) {
                    // .identifier => |id| {
                    //     if (!std.mem.eql(u8, id.value, "print")) {
                    //         std.debug.panic("Not implemented: function call other than print\n", .{});
                    //     }
                    //
                    //     try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT), 1);
                    // },
                    else => std.debug.panic("Not implemented: function call\n", .{}),
                }
            },
            .primary => |p| try emit_primary_expresion(chunk, p),
            .binary => std.debug.panic("Not implemented: bytecode from binary expression\n", .{}),
        }
    }

    fn emit_primary_expresion(chunk: *Chunk, exp: *m_syntax.PrimaryExpression) !void {
        switch (exp.*) {
            .float => |t_float| {
                // put the float at the top of the stack
                const float_value = try std.fmt.parseFloat(f64, t_float.value);

                // Add to the constants section
                const constant_idx = try chunk.write_constant(float_value);
                // Push to stack
                try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 1);
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
