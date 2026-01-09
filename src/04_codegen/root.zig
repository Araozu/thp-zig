const std = @import("std");
const m_syntax = @import("syntax");
const m_semantic = @import("semantic");

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
    pub fn emit(self: *Self) !void {
        _ = self;
        @panic("Not implemented");
    }

    pub fn deinit() void {
        //
    }
};
