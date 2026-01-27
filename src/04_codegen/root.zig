const std = @import("std");
const vm = @import("vm");
const m_syntax = @import("syntax");
const m_semantic = @import("semantic");

const Chunk = vm.Chunk;
const OpCode = vm.OpCode;
const ASTModule = m_syntax.Module;
const SemanticContext = m_semantic.SemanticContext;
const RegisterRef = m_semantic.RegisterRef;

const emit_statatement = @import("./statement.zig").emit_statement;

pub const BytecodeError = error{ OutOfMemory, InvalidCharacter, Overflow };

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

pub fn emit_ast(ctx: *CodegenContext, ast: *const ASTModule) !void {
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
    var block_ctx = BlockContext{
        .val_reg_count = reg_value_count,
        .ref_reg_count = reg_ref_count,
    };

    for (ast.statements.items) |*statement| {
        try emit_statatement(ctx, statement, &block_ctx);
    }
}
