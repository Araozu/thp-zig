const std = @import("std");
const m_syntax = @import("syntax");
const m_semantic = @import("semantic");
const m_vm = @import("vm");

const Chunk = m_vm.Chunk;
const OpCode = m_vm.OpCode;
const ASTModule = m_syntax.Module;
const SemanticContext = m_semantic.SemanticContext;

pub const ByteCodeGenerator = struct {
    ast: *const ASTModule,
    allocator: std.mem.Allocator,
    semantic_ctx: *SemanticContext,

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
                .variableBinding => |b| {
                    // ignore the binding itself, focus on the expresion
                    try self.emit_pratt_expression(&chunk, &b.expression);
                },
                .expression => |e| {
                    try self.emit_pratt_expression(&chunk, e);
                },
            }
        }

        try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 0);

        return chunk;
    }

    /// What does this do? it computes the bytecode for an expression,
    /// and has the top of the stack ready to use that computed value
    fn emit_pratt_expression(self: *Self, chunk: *Chunk, exp: *m_syntax.PrattExpression) !void {
        switch (exp.*) {
            .function => |*expr_fn_call| {
                // new workflow for `print` builtin:
                // - check the type of the arg
                // - emit the arg
                // - emit to_string if needed
                // - emit OP_PRINT

                // call the function, if `print`
                switch (expr_fn_call.callee.*) {
                    .primary => |primary| {
                        switch (primary.expr.*) {
                            .identifier => |id| {
                                if (std.mem.eql(u8, id.value, "print")) {
                                    // check type of arg, should be only one
                                    if (expr_fn_call.arguments.items.len != 1) {
                                        std.debug.panic("Expected `print` to have exactly 1 argument, found {d}.\n", .{expr_fn_call.arguments.items.len});
                                    }

                                    const arg_print = expr_fn_call.arguments.items[0];
                                    // check type from the type map
                                    const t_arg_print = self.semantic_ctx.type_map.get(arg_print.get_id()) orelse {
                                        std.debug.panic("Type for the argument of print not found. This is a bug in the compiler.\n", .{});
                                    };

                                    // Do something per type
                                    switch (t_arg_print.computed_type) {
                                        // FIXME: it says I64 but it's u64
                                        .I64 => {
                                            try self.emit_pratt_expression(chunk, arg_print);
                                            try chunk.write_chunk(@intFromEnum(OpCode.OP_U64_TO_STRING), 1);
                                        },
                                        .F64 => {
                                            try self.emit_pratt_expression(chunk, arg_print);
                                            try chunk.write_chunk(@intFromEnum(OpCode.OP_F64_TO_STRING), 1);
                                        },
                                        .String => try self.emit_pratt_expression(chunk, arg_print),
                                        else => {
                                            std.debug.panic("Not implemented: print for type `{s}`\n", .{t_arg_print.computed_type.to_str()});
                                        },
                                    }

                                    try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT), 1);
                                } else {
                                    std.debug.panic("Not implemented: function call other than print\n", .{});
                                }
                            },
                            else => std.debug.panic("Not implemented: not identifier function call\n", .{}),
                        }
                        return;
                    },
                    else => std.debug.panic("Not implemented: function call\n", .{}),
                }
            },
            .primary => |p| try emit_primary_expresion(chunk, p.expr),
            .binary => |*binary| {
                // HACK: hardcoded binary operators

                // emit for left and right
                // TODO: how to know when to promote?
                try self.emit_pratt_expression(chunk, binary.left);
                try self.emit_pratt_expression(chunk, binary.right);

                const node_type_info = self.semantic_ctx.type_map.get(binary.id) orelse {
                    // FIXME: better error message
                    std.debug.panic("Type not found for binary expression. This is a Semantic Analysis bug in the compiler\n", .{});
                };
                const t_op_result = node_type_info.computed_type;

                // emit opcode per operator & type
                if (std.mem.eql(u8, binary.operator.value, "+")) {
                    switch (t_op_result) {
                        .F64 => try chunk.write_chunk(@intFromEnum(OpCode.OP_ADD_F64), 1),
                        .I64 => try chunk.write_chunk(@intFromEnum(OpCode.OP_ADD_U64), 1),
                        else => {
                            std.debug.panic("Not implemented: add operator on type `{s}`\n", .{t_op_result.to_str()});
                        },
                    }
                } else if (std.mem.eql(u8, binary.operator.value, "-")) {
                    switch (t_op_result) {
                        .F64 => try chunk.write_chunk(@intFromEnum(OpCode.OP_SUB_F64), 1),
                        .I64 => try chunk.write_chunk(@intFromEnum(OpCode.OP_SUB_U64), 1),
                        else => {
                            std.debug.panic("Not implemented: add operator on type `{s}`\n", .{t_op_result.to_str()});
                        },
                    }
                } else if (std.mem.eql(u8, binary.operator.value, "++")) {
                    try chunk.write_chunk(@intFromEnum(OpCode.OP_CONCAT), 1);
                } else {
                    std.debug.panic("Not implemented: operator `{s}`\n", .{binary.operator.value});
                }
            },
        }
    }

    fn emit_primary_expresion(chunk: *Chunk, exp: *m_syntax.PrimaryExpression) !void {
        switch (exp.*) {
            // HACK: assumed to be f64
            .float => |tok_float| {
                // put the float at the top of the stack
                const float_value = try std.fmt.parseFloat(f64, tok_float.value);

                // Add to the constants section
                const constant_idx = try chunk.write_constant(@bitCast(float_value));
                // Push to stack
                try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 1);
                try chunk.write_chunk(@intCast(constant_idx), 123);
            },
            // HACK: assumed to be u64
            .int => |tok_int| {
                const int_value = try std.fmt.parseInt(u64, tok_int.value, 10);

                // Add to the constants section
                const constant_idx = try chunk.write_constant(int_value);

                // Push to stack
                try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 1);
                try chunk.write_chunk(@intCast(constant_idx), 123);
            },
            .string => |tok_string| {
                // NOTE: OP_REF
                const str_value = tok_string.value[1 .. tok_string.value.len - 1];
                const obj_string_ptr: u64 = try chunk.create_string(str_value);

                {
                    // Write the pointer as a constant
                    const constant_idx = try chunk.write_constant(obj_string_ptr);

                    try chunk.write_chunk(@intFromEnum(OpCode.OP_REF), 1);
                    try chunk.write_chunk(@intCast(constant_idx), 1);
                }
            },
            else => {
                // TODO
                std.debug.panic("Not implemented: codegen other primary expr\n", .{});
            },
        }
    }

    pub fn deinit() void {
        //
    }
};
