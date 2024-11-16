const std = @import("std");
const number = @import("./number.zig");
const token = @import("./token.zig");

const TokenType = token.TokenType;
const Token = token.Token;

pub fn tokenize(input: []const u8) !void {
    const input_len = input.len;
    const next_token = try number.lex(input, input_len, 0);

    if (next_token) |tuple| {
        const t = tuple[0];

        std.debug.print("{s}\n", .{t.value});
    } else {
        std.debug.print("no token found :c", .{});
    }
}
