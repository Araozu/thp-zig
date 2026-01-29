const std = @import("std");
const syntax = @import("syntax");
const semantic = @import("semantic");

const root = @import("./root.zig");
const expression = @import("./expression.zig");

const BytecodeError = root.BytecodeError;
const RegisterRef = semantic.RegisterRef;
const CodegenContext = root.CodegenContext;
const BlockContext = root.BlockContext;

pub fn emit_function_call(
    ctx: *CodegenContext,
    block_ctx: *BlockContext,
    exp: *const syntax.PrattExpression.Function,
) BytecodeError!RegisterRef {
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

    // By this point Semantic should have ensured param types are OK
    std.debug.assert(exp.arguments.items.len == 1);

    const exp_str = exp.arguments.items[0];

    // Emit string (through pratt emitter) w a dummy register
    const rfx = block_ctx.ref_reg_count;
    const temp_reg: RegisterRef = .{ .ref = rfx };
    block_ctx.ref_reg_count += 1;
    defer block_ctx.ref_reg_count -= 1;

    const out_reg = (try expression.emit_expression(ctx, block_ctx, exp_str, temp_reg)).as_ref();

    // Emit print opcode
    try ctx.chunk.write_opcode(.op_print);
    try ctx.chunk.write_byte(rfx);

    // A print doesnt set anything in regs, and semantic should've known.
    // Also the caller should not use this path.
    return .{ .ref = out_reg };
}
