const std = @import("std");
const errors = @import("errors");
const lexic = @import("lexic");

const LexResult = struct {
    tokens: std.ArrayList(lexic.Token),
    error_array: std.ArrayList(errors.ErrorData),
};

pub fn tokenize_to_json() !void {
    // setup stdin, stdout and allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // read up to 8192 bytes from stdin until EOF
    var buffer: [8192]u8 = undefined;
    const stdin = std.io.getStdIn();
    const bytes_read = try stdin.readAll(&buffer);

    const bytes = buffer[0..bytes_read];

    // tokenize
    var error_array = std.ArrayList(errors.ErrorData).init(alloc);
    defer error_array.deinit();

    const tokens = try lexic.tokenize(bytes, alloc, &error_array);
    defer tokens.deinit();

    // serialize & print json to stdout
    var json_arrl = std.ArrayList(u8).init(alloc);
    defer json_arrl.deinit();
    var json_writer = json_arrl.writer();

    try json_writer.writeAll("{\"errors\":[");

    const errors_len = error_array.items.len - 1;
    for (error_array.items, 0..) |err, idx| {
        try err.write_json(alloc, json_writer);

        // write a comma only if there are items left
        if (idx < errors_len) {
            try json_writer.writeAll(",");
        }
    }
    try json_writer.writeAll("],\"tokens\":");

    // write tokens as JSON
    const tokens_json = try std.json.stringifyAlloc(alloc, tokens.items, .{});
    defer alloc.free(tokens_json);

    try json_writer.writeAll(tokens_json);

    try json_writer.writeAll("}");

    try stdout.print("{s}", .{json_arrl.items});
    try bw.flush();

    // the end
}
