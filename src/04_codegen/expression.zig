const std = @import("std");
const syntax = @import("syntax");
const semantic = @import("semantic");

const root = @import("./root.zig");
const emit_function_call = @import("./function_call.zig").emit_function_call;

const BytecodeError = root.BytecodeError;
const RegisterRef = semantic.RegisterRef;
const CodegenContext = root.CodegenContext;
const BlockContext = root.BlockContext;

pub fn emit_expression(
    ctx: *CodegenContext,
    block_ctx: *BlockContext,
    node: *const syntax.PrattExpression,
    target_slot: RegisterRef,
) BytecodeError!RegisterRef {
    return switch (node.*) {
        .primary => |*primary| try emit_primary_expression(ctx, primary.expr, target_slot),
        .binary => |*binary| try emit_binary_expression(ctx, block_ctx, binary, target_slot),
        .function => |*function| try emit_function_call(ctx, block_ctx, function),
    };
}

fn emit_binary_expression(
    ctx: *CodegenContext,
    block_ctx: *BlockContext,
    exp_binary: *const syntax.PrattExpression.Binary,
    target_slot: RegisterRef,
) BytecodeError!RegisterRef {
    const node_type_info = ctx.semantic_ctx.type_map.get(exp_binary.id) orelse {
        // FIXME: better error message
        std.debug.panic("Type not found for binary expression. This is a Semantic Analysis bug in the compiler\n", .{});
    };
    // FIXME: do stuff with the expected type
    const t_op_result = node_type_info.computed_type;
    _ = t_op_result;

    const rvx = target_slot.as_val();
    const rva = block_ctx.val_reg_count;
    const rvb = block_ctx.val_reg_count + 1;
    block_ctx.val_reg_count += 2;
    defer block_ctx.val_reg_count -= 2;

    _ = (try emit_expression(ctx, block_ctx, exp_binary.left, .{ .val = rva })).as_val();
    _ = (try emit_expression(ctx, block_ctx, exp_binary.right, .{ .val = rvb })).as_val();

    if (std.mem.eql(u8, exp_binary.operator.value, "+")) {
        try ctx.chunk.write_opcode(.op_add);
        try ctx.chunk.write_byte(rvx);
        try ctx.chunk.write_byte(rva);
        try ctx.chunk.write_byte(rvb);

        return .{ .val = rvx };
    } else {
        @panic("Unsupported operator");
    }

    @panic("Not implemented");
}

/// Creates the value & returns its register number
fn emit_primary_expression(
    ctx: *CodegenContext,
    exp: *const syntax.PrimaryExpression,
    target_slot: RegisterRef,
) BytecodeError!RegisterRef {
    switch (exp.*) {
        // HACK: assumed to be u64
        .int => |tok_int| {
            const rx_idx = target_slot.as_val();
            const int_value = try std.fmt.parseInt(u64, tok_int.value, 10);

            // Add to the constants section
            const constant_idx = try ctx.chunk.write_constant(int_value);

            // Save to register
            try ctx.chunk.write_opcode(.op_load);
            try ctx.chunk.write_byte(rx_idx);
            try ctx.chunk.write_byte(@intCast(constant_idx));

            return .{ .val = rx_idx };
        },
        .string => |tok_string| {
            const rx_idx = target_slot.as_ref();
            const string_ptr = try ctx.chunk.create_static_string(tok_string.value[1..(tok_string.value.len - 1)]);

            // Save pointer in constants
            const const_idx = try ctx.chunk.write_constant(string_ptr);

            try ctx.chunk.write_opcode(.op_load_ref);
            try ctx.chunk.write_byte(rx_idx);
            try ctx.chunk.write_byte(@intCast(const_idx));

            return .{ .ref = rx_idx };
        },
        else => {
            std.debug.panic("Not implemented: codegen other primary expr\n", .{});
        },
    }
}
