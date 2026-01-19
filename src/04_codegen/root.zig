const std = @import("std");
const vm = @import("vm");
const m_syntax = @import("syntax");
const m_semantic = @import("semantic");

const Chunk = vm.Chunk;
const OpCode = vm.OpCode;
const ASTModule = m_syntax.Module;
const SemanticContext = m_semantic.SemanticContext;
const RegisterRef = m_semantic.RegisterRef;

const BytecodeError = error{ OutOfMemory, InvalidCharacter, Overflow };

/// Context for a block of code, to keep track of locals
///
/// When entering a block, a new BlockContext is created to track locals.
/// The new block should reserve n registers for its locals, and then
/// other operations use the registers after that.
pub const BlockContext = struct {
    val_reg_count: u8,
    ref_reg_count: u8,
};

pub const CodegenContext = struct {
    allocator: std.mem.Allocator,
    semantic_ctx: *SemanticContext,
    chunk: *Chunk,

    const Self = @This();

    pub fn init(
        self: *Self,
        alloc: std.mem.Allocator,
        semantic_ctx: *SemanticContext,
        chunk: *Chunk,
    ) void {
        self.* = .{
            .allocator = alloc,
            .semantic_ctx = semantic_ctx,
            .chunk = chunk,
        };
    }
};

pub fn emit_ast(ctx: *CodegenContext, ast: *const ASTModule) void {
    //
    // Count the number of variables to allocate registers for
    //
    var reg_value_count: u8 = 0;
    var reg_ref_count: u8 = 0;

    for (ast.statements.items) |*statement| {
        switch (statement.*) {
            .variableBinding => |binding| {
                const binding_symbol_info = ctx.semantic_ctx.type_map.get(binding.id) orelse {
                    @panic("Variable has no allocated register - semantic analysis bug");
                };

                const t_binding = binding_symbol_info.computed_type;
                std.debug.assert(t_binding != .Unit);
                std.debug.assert(t_binding != .Untyped);

                if (t_binding.is_primitive()) {
                    reg_value_count += 1;
                } else {
                    reg_ref_count += 1;
                }
            },
            else => {},
        }
    }

    // Create a block context
    const block_ctx = BlockContext{
        .val_reg_count = reg_value_count,
        .ref_reg_count = reg_ref_count,
    };
    _ = block_ctx;

    // TODO: Emit bytecode for each statement
}

/// Legacy: Generates a Chunk of bytecode for the Register VM
pub const ByteCodeGenerator = struct {
    ast: *const ASTModule,
    allocator: std.mem.Allocator,
    semantic_ctx: *SemanticContext,
    current_val_reg: u8 = 0,
    current_ref_reg: u8 = 0,

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

    fn emit_variable_binding(self: *Self, chunk: *Chunk, binding: *m_syntax.VariableBinding) void {
        _ = self;
        _ = chunk;
        _ = binding;
        @panic("Not implemented: variable binding codegen");
    }

    /// Computes the bytecode for an expression,
    /// stores the result in a value register, and returns its number
    fn emit_pratt_expression(self: *Self, chunk: *Chunk, exp: *m_syntax.PrattExpression) BytecodeError!RegisterRef {
        return switch (exp.*) {
            .function => |*f| try self.emit_function_call_expression(chunk, f),
            .primary => |p| try self.emit_primary_expresion(chunk, p.expr),
            .binary => |*exp_binary| {
                const node_type_info = self.semantic_ctx.type_map.get(exp_binary.id) orelse {
                    // FIXME: better error message
                    std.debug.panic("Type not found for binary expression. This is a Semantic Analysis bug in the compiler\n", .{});
                };
                // FIXME: do stuff with the expected type
                const t_op_result = node_type_info.computed_type;
                _ = t_op_result;

                const ra_idx = (try self.emit_pratt_expression(chunk, exp_binary.left)).as_val();
                const rb_idx = (try self.emit_pratt_expression(chunk, exp_binary.right)).as_val();

                if (std.mem.eql(u8, exp_binary.operator.value, "+")) {
                    try chunk.write_opcode(.op_add);
                    try chunk.write_byte(ra_idx);
                    try chunk.write_byte(ra_idx);
                    try chunk.write_byte(rb_idx);

                    // Reuse registers
                    self.current_val_reg = ra_idx + 1;

                    return .{ .val = ra_idx };
                } else {
                    @panic("Unsupported operator");
                }
            },
        };
    }

    fn emit_function_call_expression(self: *Self, chunk: *Chunk, exp: *m_syntax.PrattExpression.Function) !RegisterRef {
        //
        //  `print` builtin
        //
        switch (exp.callee.*) {
            .primary => |*primary| {
                switch (primary.expr.*) {
                    .identifier => |t_id| {
                        if (!std.mem.eql(u8, t_id.value, "print")) {
                            // FIXME: proper error handling
                            @panic("Not implemented: function that is not `print`");
                        }
                    },
                    // FIXME: proper error handling
                    else => @panic("Not implemented: function expression that is not `print`"),
                }
            },
            else => @panic("Not implemented: function expression that is not `print`"),
        }

        // Semantic should have ensured params are OK
        std.debug.assert(exp.arguments.items.len == 1);

        const exp_str = exp.arguments.items[0];

        // Emit string (through pratt emitter)
        const out_reg = (try self.emit_pratt_expression(chunk, exp_str)).as_ref();

        // Emit print opcode
        try chunk.write_opcode(.op_print);
        try chunk.write_byte(out_reg);

        // A print doesnt set anything in regs, and semantic should've known.
        // Also the caller should not use this path.
        return .{ .ref = out_reg };
    }

    /// Creates the value & returns its register number
    fn emit_primary_expresion(self: *Self, chunk: *Chunk, exp: *m_syntax.PrimaryExpression) BytecodeError!RegisterRef {
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

                return .{ .val = reg_number };
            },
            .string => |tok_string| {
                const string_ptr = try chunk.create_static_string(tok_string.value[1..(tok_string.value.len - 1)]);
                const reg_ref_idx = self.current_ref_reg;
                self.current_ref_reg += 1;

                // Save pointer in constants
                const const_idx = try chunk.write_constant(string_ptr);

                try chunk.write_opcode(.op_load_ref);
                try chunk.write_byte(reg_ref_idx);
                try chunk.write_byte(@intCast(const_idx));

                return .{ .ref = reg_ref_idx };
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
