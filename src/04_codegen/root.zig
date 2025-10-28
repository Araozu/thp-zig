const std = @import("std");
const syntax = @import("syntax");
const m_vm = @import("vm");

const Chunk = m_vm.Chunk;
const OpCode = m_vm.OpCode;
const ASTModule = syntax.Module;

pub const ByteCodeGenerator = struct {
    ast: *const ASTModule,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(self: *Self, ast: *const ASTModule, alloc: std.mem.Allocator) void {
        self.* = .{
            .ast = ast,
            .allocator = alloc,
        };
    }

    /// Caller must call `deinit` on the returned chunk
    pub fn emit(self: *Self) !Chunk {
        var chunk: Chunk = undefined;
        chunk.init(self.allocator);
        errdefer chunk.deinit();

        // write bytes
        {
            const constant_idx = try chunk.write_constant(1.2);
            try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 123);
            try chunk.write_chunk(@intCast(constant_idx), 123);
        }
        {
            const constant_idx = try chunk.write_constant(4.8);
            try chunk.write_chunk(@intFromEnum(OpCode.OP_CONSTANT), 123);
            try chunk.write_chunk(@intCast(constant_idx), 123);
        }

        try chunk.write_chunk(@intFromEnum(OpCode.OP_PRINT), 123);
        try chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 0);

        return chunk;
    }

    pub fn deinit() void {
        //
    }
};
