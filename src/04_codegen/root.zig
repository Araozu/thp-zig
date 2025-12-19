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
            .function => |*f| {
                // Emit bytecode for the args
                for (f.arguments.items) |argument| {
                    try self.emit_pratt_expression(chunk, argument);
                }

                // call the function, if `print`
                switch (f.callee.*) {
                    .primary => |primary| {
                        switch (primary.*) {
                            .identifier => |id| {
                                if (std.mem.eql(u8, id.value, "print")) {
                                    try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT_F64), 1);
                                } else if (std.mem.eql(u8, id.value, "prints")) {
                                    try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT_CONST), 1);
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
            .primary => |p| try emit_primary_expresion(chunk, p),
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
