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

    pub fn emit(self: *Self) []u8 {
        var chunk: Chunk = undefined;
        chunk.init(self.allocator);
        defer chunk.deinit();

        // write bytes
        chunk.write_chunk(@intFromEnum(OpCode.OP_RETURN), 0);

        // write bytes
        for (chunk.code.items) |byte| {
            std.debug.print("0x{X}", .{byte});
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit() void {
        //
    }
};
