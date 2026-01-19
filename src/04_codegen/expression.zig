const std = @import("std");
const syntax = @import("syntax");

const CodegenContext = @import("./root.zig").CodegenContext;
const BlockContext = @import("./root.zig").BlockContext;

pub fn emit_expression(ctx: *CodegenContext, node: *const syntax.PrattExpression, block_ctx: *const BlockContext) void {
    _ = block_ctx;

    switch (node.*) {
        .primary => |primary| try emit_primary_expresion(ctx, primary.expr),
    }
}

/// Creates the value & returns its register number
fn emit_primary_expresion(
    ctx: *CodegenContext,
    exp: *const syntax.PrimaryExpression,
    block_ctx: *const BlockContext,
) void {
    switch (exp.*) {
        // HACK: assumed to be u64
        .int => |tok_int| {
            const int_value = try std.fmt.parseInt(u64, tok_int.value, 10);

            // Add to the constants section
            const constant_idx = try ctx.chunk.write_constant(int_value);
            const reg_number = block_ctx.current_val_reg;
            block_ctx.current_val_reg += 1;

            // Save to register
            try ctx.chunk.write_opcode(.op_load);
            try ctx.chunk.write_byte(reg_number);
            try ctx.chunk.write_byte(@intCast(constant_idx));

            // return .{ .val = reg_number };
        },
        .string => |tok_string| {
            const string_ptr = try ctx.chunk.create_static_string(tok_string.value[1..(tok_string.value.len - 1)]);
            const reg_ref_idx = block_ctx.current_ref_reg;
            block_ctx.current_ref_reg += 1;

            // Save pointer in constants
            const const_idx = try ctx.chunk.write_constant(string_ptr);

            try ctx.chunk.write_opcode(.op_load_ref);
            try ctx.chunk.write_byte(reg_ref_idx);
            try ctx.chunk.write_byte(@intCast(const_idx));

            // return .{ .ref = reg_ref_idx };
        },
        else => {
            std.debug.panic("Not implemented: codegen other primary expr\n", .{});
        },
    }
}
