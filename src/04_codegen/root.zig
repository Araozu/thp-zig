const std = @import("std");
const vm = @import("vm");
const m_syntax = @import("syntax");
const m_semantic = @import("semantic");

const Chunk = vm.Chunk;
const OpCode = vm.OpCode;
const ASTModule = m_syntax.Module;
const SemanticContext = m_semantic.SemanticContext;

/// Generates a Chunk of bytecode for the Register VM
pub const ByteCodeGenerator = struct {
    ast: *const ASTModule,
    allocator: std.mem.Allocator,
    semantic_ctx: *SemanticContext,
    current_val_reg: u8 = 0,

    const Self = @This();

    pub fn init(self: *Self, ast: *const ASTModule, semantic_ctx: *SemanticContext, alloc: std.mem.Allocator) void {
        self.* = .{
            .ast = ast,
            .allocator = alloc,
            .semantic_ctx = semantic_ctx,
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
                // .variableBinding => |b| try self.emit_variable_binding(&chunk, b),
                .expression => |e| {
                    _ = try self.emit_pratt_expression(&chunk, e);
                },
                else => @panic("Not implemented in codegen"),
            }
        }

        try chunk.write_opcode(OpCode.op_return);

        return chunk;
    }

    /// What does this do? it computes the bytecode for an expression,
    /// and has the top of the stack ready to use that computed value
    fn emit_pratt_expression(self: *Self, chunk: *Chunk, exp: *m_syntax.PrattExpression) !u8 {
        return switch (exp.*) {
            // FIXME: ???
            .primary => |p| try self.emit_primary_expresion(chunk, p.expr),
            else => @panic("Not implemented: codegen pratt"),
        };
    }

    /// Creates the value & returns its register number
    fn emit_primary_expresion(self: *Self, chunk: *Chunk, exp: *m_syntax.PrimaryExpression) !u8 {
        switch (exp.*) {
            // HACK: assumed to be u64
            .int => |tok_int| {
                const int_value = try std.fmt.parseInt(u64, tok_int.value, 10);

                // Add to the constants section
                const constant_idx = try chunk.write_constant(int_value);
                const reg_number = self.current_val_reg;
                self.current_val_reg += 1;

                // Save to register
                try chunk.write_opcode(.op_load);
                try chunk.write_byte(reg_number);
                try chunk.write_byte(@intCast(constant_idx));

                return reg_number;
            },
            else => {
                std.debug.panic("Not implemented: codegen other primary expr\n", .{});
            },
        }
    }

    pub fn deinit() void {
        //
    }
};
