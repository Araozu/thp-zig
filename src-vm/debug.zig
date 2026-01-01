const std = @import("std");
const m_chunk = @import("./chunk.zig");
const m_value = @import("./value.zig");

const Chunk = m_chunk.Chunk;
const OpCode = m_chunk.OpCode;

pub fn dissasemble_chunk(chunk: *Chunk, name: []const u8) void {
    std.debug.print("== {s} ==\n", .{name});

    const len = chunk.code.items.len;
    var pos: usize = 0;
    while (pos < len) {
        pos = dissasemble_instruction(chunk, pos);
    }
}

pub fn dissasemble_instruction(chunk: *Chunk, offset: usize) usize {
    std.debug.print("  {X:0>4} ", .{offset});

    // print line number
    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        std.debug.print("   | ", .{});
    } else {
        std.debug.print("{d:>4} ", .{chunk.lines.items[offset]});
    }

    const instruction = chunk.code.items[offset];
    const e_instruction: OpCode = @enumFromInt(instruction);
    switch (e_instruction) {
        .OP_RETURN => |op| return simple_instruction(@tagName(op), offset),
        .OP_CONSTANT => |op| return constant_pool_instruction(@tagName(op), chunk, offset),
        .OP_REF => |op| return constant_pool_instruction(@tagName(op), chunk, offset),
        .OP_STORE => |op| return constant_inline_instruction(@tagName(op), chunk, offset),
        .OP_LOAD => |op| return constant_inline_instruction(@tagName(op), chunk, offset),
        else => return simple_instruction(@tagName(e_instruction), offset),
    }

    return 0;
}

fn simple_instruction(name: []const u8, offset: usize) usize {
    std.debug.print("{s}\n", .{name});
    return offset + 1;
}

fn constant_inline_instruction(name: []const u8, chunk: *Chunk, offset: usize) usize {
    const constant_idx = chunk.code.items[offset + 1];
    std.debug.print("{s:<16} @{d:<4}\n", .{ name, constant_idx });
    return offset + 2;
}

fn constant_pool_instruction(name: []const u8, chunk: *Chunk, offset: usize) usize {
    const constant_idx = chunk.code.items[offset + 1];
    std.debug.print("{s:<16} @{d:<4} (", .{ name, constant_idx });
    // m_value.print_value(chunk.constants.items[constant_idx]);
    std.debug.print("{d}", .{chunk.constants.items[constant_idx]});
    std.debug.print(")\n", .{});
    return offset + 2;
}
