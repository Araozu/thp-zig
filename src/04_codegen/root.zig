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
                    const ra_idx = try self.emit_pratt_expression(&chunk, e);
                    _ = ra_idx;
                    // HACK: manually print the value
                    // try chunk.write_opcode(.op_dprint);
                    // try chunk.write_byte(ra_idx);
                },
                else => @panic("Not implemented in codegen"),
            }
        }

        try chunk.write_opcode(OpCode.op_return);

        return chunk;
    }

    /// Computes the bytecode for an expression,
    /// stores the result in a value register, and returns its number
    fn emit_pratt_expression(self: *Self, chunk: *Chunk, exp: *m_syntax.PrattExpression) !u8 {
        return switch (exp.*) {
            .primary => |p| try self.emit_primary_expresion(chunk, p.expr),
            .binary => |*exp_binary| {
                const node_type_info = self.semantic_ctx.type_map.get(exp_binary.id) orelse {
                    // FIXME: better error message
                    std.debug.panic("Type not found for binary expression. This is a Semantic Analysis bug in the compiler\n", .{});
                };
                // FIXME: do stuff with the expected type
                const t_op_result = node_type_info.computed_type;
                _ = t_op_result;

                const ra_idx = try self.emit_pratt_expression(chunk, exp_binary.left);
                const rb_idx = try self.emit_pratt_expression(chunk, exp_binary.right);

                if (std.mem.eql(u8, exp_binary.operator.value, "+")) {
                    try chunk.write_opcode(.op_add);
                    try chunk.write_byte(ra_idx);
                    try chunk.write_byte(ra_idx);
                    try chunk.write_byte(rb_idx);

                    // Reuse registers
                    self.current_val_reg = ra_idx + 1;

                    return ra_idx;
                } else {
                    @panic("Unsupported operator");
                }
            },
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
