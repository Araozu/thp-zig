const std = @import("std");
const syntax = @import("syntax");
const semantic = @import("semantic");

const root = @import("./root.zig");
const emit_function_call = @import("./function_call.zig").emit_function_call;

const BytecodeError = root.BytecodeError;
const RegisterRef = semantic.RegisterRef;
const CodegenContext = root.CodegenContext;
const BlockContext = root.BlockContext;

pub fn emit_expression(ctx: *CodegenContext, block_ctx: *BlockContext, node: *const syntax.PrattExpression) BytecodeError!RegisterRef {
    return switch (node.*) {
        .primary => |*primary| try emit_primary_expression(ctx, block_ctx, primary.expr),
        .binary => |*binary| try emit_binary_expression(ctx, block_ctx, binary),
        .function => |*function| try emit_function_call(ctx, block_ctx, function),
    };
}

fn emit_binary_expression(
    ctx: *CodegenContext,
    block_ctx: *BlockContext,
    exp_binary: *const syntax.PrattExpression.Binary,
) BytecodeError!RegisterRef {
    //
    const node_type_info = ctx.semantic_ctx.type_map.get(exp_binary.id) orelse {
        // FIXME: better error message
        std.debug.panic("Type not found for binary expression. This is a Semantic Analysis bug in the compiler\n", .{});
    };
    // FIXME: do stuff with the expected type
    const t_op_result = node_type_info.computed_type;
    _ = t_op_result;

    const ra_idx = (try emit_expression(ctx, block_ctx, exp_binary.left)).as_val();
    const rb_idx = (try emit_expression(ctx, block_ctx, exp_binary.right)).as_val();

    if (std.mem.eql(u8, exp_binary.operator.value, "+")) {
        try ctx.chunk.write_opcode(.op_add);
        try ctx.chunk.write_byte(ra_idx);
        try ctx.chunk.write_byte(ra_idx);
        try ctx.chunk.write_byte(rb_idx);

        // Reuse registers by setting the next to ra + 1
        block_ctx.val_reg_count = ra_idx + 1;

        return .{ .val = ra_idx };
    } else {
        @panic("Unsupported operator");
    }

    @panic("Not implemented");
}

/// Creates the value & returns its register number
fn emit_primary_expression(
    ctx: *CodegenContext,
    block_ctx: *BlockContext,
    exp: *const syntax.PrimaryExpression,
) BytecodeError!RegisterRef {
    switch (exp.*) {
        // HACK: assumed to be u64
        .int => |tok_int| {
            const int_value = try std.fmt.parseInt(u64, tok_int.value, 10);

            // Add to the constants section
            const constant_idx = try ctx.chunk.write_constant(int_value);
            const reg_number = block_ctx.val_reg_count;
            block_ctx.val_reg_count += 1;

            // Save to register
            try ctx.chunk.write_opcode(.op_load);
            try ctx.chunk.write_byte(reg_number);
            try ctx.chunk.write_byte(@intCast(constant_idx));

            return .{ .val = reg_number };
        },
        .string => |tok_string| {
            const string_ptr = try ctx.chunk.create_static_string(tok_string.value[1..(tok_string.value.len - 1)]);
            const reg_ref_idx = block_ctx.ref_reg_count;
            block_ctx.ref_reg_count += 1;

            // Save pointer in constants
            const const_idx = try ctx.chunk.write_constant(string_ptr);

            try ctx.chunk.write_opcode(.op_load_ref);
            try ctx.chunk.write_byte(reg_ref_idx);
            try ctx.chunk.write_byte(@intCast(const_idx));

            return .{ .ref = reg_ref_idx };
        },
        else => {
            std.debug.panic("Not implemented: codegen other primary expr\n", .{});
        },
    }
}
