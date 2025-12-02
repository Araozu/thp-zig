const std = @import("std");
const m_chunk = @import("./chunk.zig");
const m_debug = @import("./debug.zig");
const m_vm = @import("./vm.zig");
const m_reader = @import("./reader.zig");

pub const VM = m_vm.VM;
pub const Chunk = m_chunk.Chunk;
pub const OpCode = m_chunk.OpCode;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    var allocator = gpa.allocator();

    // Read bytes
    var args = std.process.args();
    defer args.deinit();

    // Ignore executable name
    _ = args.next();

    const input_filename = args.next() orelse std.debug.panic("No bytecode input file\n", .{});

    // Read file
    var filebuffer: [4096]u8 = undefined;
    const absolute_path = try std.fs.realpath(input_filename, &filebuffer);

    const source_file = try std.fs.createFileAbsolute(absolute_path, std.fs.File.CreateFlags{
        .read = true,
        .truncate = false,
    });

    // 20MB max buffer
    var file_buffer = try allocator.alloc(u8, 1024 * 1024 * 20);
    defer allocator.free(file_buffer);

    const read_bytes = try source_file.read(file_buffer);
    const file_bytes = file_buffer[0..read_bytes];

    // Build from bytes
    var chunk = try m_reader.read_bytecode(allocator, file_bytes);
    defer chunk.deinit();

    var vm: m_vm.VM = undefined;
    vm.init(chunk);
    defer vm.deinit();

    _ = vm.interpret();
}
