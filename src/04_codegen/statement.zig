const std = @import("std");
const syntax = @import("syntax");

const CodegenContext = @import("./root.zig").CodegenContext;
const BlockContext = @import("./root.zig").BlockContext;
const Statement = syntax.Statement;
const emit_expression = @import("./expression.zig").emit_expression;

pub fn emit_statement(ctx: *CodegenContext, node: *const Statement, block_ctx: *BlockContext) !void {
    _ = switch (node.*) {
        .expression => |expression| try emit_expression(ctx, block_ctx, expression),
        .variableBinding => {
            @panic("Codegen: not implemented for variableBinding statements");
        },
    };
}
