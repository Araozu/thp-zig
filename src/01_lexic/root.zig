const std = @import("std");
const number = @import("./number.zig");
const token = @import("./token.zig");

const TokenType = token.TokenType;
const Token = token.Token;

pub fn tokenize(input: []const u8, alloc: std.mem.Allocator) !void {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = std.ArrayList(Token).init(alloc);
    defer tokens.deinit();

    while (current_pos < input_len) {
        const actual_next_pos = ignore_whitespace(input, current_pos);

        const next_token = try number.lex(input, input_len, actual_next_pos);
        if (next_token) |tuple| {
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        } else {
            // no lexer matched
            std.debug.print("unmatched args: anytype:c\n", .{});
            break;
        }
    }
}

/// Ignores all whitespace on `input` since `start`
/// and returns the position where whitespace ends.
///
/// Whitespace is: tabs, spaces
pub fn ignore_whitespace(input: []const u8, start: usize) usize {
    const cap = input.len;
    var pos = start;

    while (pos < cap and (input[pos] == ' ' or input[pos] == '\t')) {
        pos += 1;
    }

    return pos;
}

test "should insert 1 item" {
    const input = "322";
    try tokenize(input, std.testing.allocator);
}

test "should insert 2 item" {
    const input = "322 644";
    try tokenize(input, std.testing.allocator);
}
