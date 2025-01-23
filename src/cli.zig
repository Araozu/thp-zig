const std = @import("std");
const errors = @import("errors");
const lexic = @import("lexic");

pub fn tokenize_to_json() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Setup buffered stdout once
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Read all stdin
    var stdin_buf = std.ArrayList(u8).init(alloc);
    defer stdin_buf.deinit();
    // 16MB, why would anyone ever have source code bigger than that??
    const max_file_size = 16 * 1024 * 1024;
    try std.io.getStdIn().reader().readAllArrayList(&stdin_buf, max_file_size);

    // Tokenize
    var error_array = std.ArrayList(errors.ErrorData).init(alloc);
    defer error_array.deinit();
    const tokens = try lexic.tokenize(stdin_buf.items, alloc, &error_array);
    defer tokens.deinit();

    // Write JSON directly to stdout
    try stdout.writeAll("{\"errors\":[");
    for (error_array.items, 0..) |err, idx| {
        try err.write_json(alloc, stdout);
        if (idx < error_array.items.len - 1) try stdout.writeAll(",");
    }
    try stdout.writeAll("],\"tokens\":");
    try std.json.stringify(tokens.items, .{}, stdout);
    try stdout.writeAll("}");
    try bw.flush();
}
