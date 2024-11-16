const std = @import("std");
const number = @import("./number.zig");
const token = @import("./token.zig");

const TokenType = token.TokenType;
const Token = token.Token;

pub fn tokenize(input: []const u8) !void {
    const input_len = input.len;
    const next_token = try number(input, input_len, 0);
    _ = next_token;

    std.debug.print("tokenize :D {s}\n", .{input});
}
