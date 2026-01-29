const std = @import("std");
const syntax = @import("syntax");

const CodegenContext = @import("./root.zig").CodegenContext;
const BlockContext = @import("./root.zig").BlockContext;
const Statement = syntax.Statement;
const emit_expression = @import("./expression.zig").emit_expression;

pub fn emit_statement(ctx: *CodegenContext, node: *const Statement, block_ctx: *BlockContext) !void {
    switch (node.*) {
        .expression => |expression| {
            // get a dummy register
            const expr_type = ctx.semantic_ctx.type_map.get(expression.get_id()).?;
            if (expr_type.computed_type.is_primitive()) {
                const rvx = block_ctx.val_reg_count;
                block_ctx.val_reg_count += 1;
                defer block_ctx.val_reg_count -= 1;

                _ = try emit_expression(ctx, block_ctx, expression, .{ .val = rvx });
            } else {
                const rfx = block_ctx.ref_reg_count;
                block_ctx.ref_reg_count += 1;
                defer block_ctx.ref_reg_count -= 1;

                _ = try emit_expression(ctx, block_ctx, expression, .{ .val = rfx });
            }
        },
        .variableBinding => |binding| _ = try emit_variable_binding(ctx, block_ctx, binding),
    }
}

pub fn emit_variable_binding(ctx: *CodegenContext, block_ctx: *BlockContext, binding: *syntax.VariableBinding) !void {
    // Get desired variable register
    const binding_info = ctx.semantic_ctx.symbol_table.scope.get(binding.identifier.value) orelse {
        @panic("Semantyc analysis bug: Binding info of variable not found in scope.");
    };

    // Compute expression, send variable register to set
    _ = try emit_expression(ctx, block_ctx, &binding.expression, binding_info.slot_index.?);
}
