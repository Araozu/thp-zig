const std = @import("std");
const assert = std.debug.assert;
const number = @import("./number.zig");
const identifier = @import("./identifier.zig");
const datatype = @import("./datatype.zig");
const token = @import("./token.zig");
const operator = @import("./operator.zig");
const comment = @import("./comment.zig");

const TokenType = token.TokenType;
const Token = token.Token;

pub fn tokenize(input: []const u8, alloc: std.mem.Allocator) !void {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = std.ArrayList(Token).init(alloc);
    defer tokens.deinit();

    while (current_pos < input_len) {
        const actual_next_pos = ignore_whitespace(input, current_pos);
        assert(current_pos <= actual_next_pos);

        // attempt to lex a number
        if (try number.lex(input, input_len, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // attempt to lex an identifier
        else if (try identifier.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // attempt to lex a datatype
        else if (try datatype.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // attempt to lex a comment
        else if (try comment.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // attempt to lex an operator
        else if (try operator.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // nothing was matched. fail
        // TODO: instead of failing add an error, ignore all chars
        // until next whitespace, and continue lexing
        // TODO: check if this is a good error recovery strategy
        else {
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
