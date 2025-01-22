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
    const json_out = try std.json.stringifyAlloc(alloc, .{
        .errors = error_array.items,
    }, .{});
    defer alloc.free(json_out);
    try stdout.print("{s}", .{json_out});
    try bw.flush();

    // the end
}
