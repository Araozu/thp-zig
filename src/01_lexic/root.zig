const std = @import("std");
const assert = std.debug.assert;
const number = @import("number.zig");
const identifier = @import("identifier.zig");
const datatype = @import("datatype.zig");
const token = @import("token.zig");
const operator = @import("operator.zig");
const comment = @import("comment.zig");
const string = @import("string.zig");
const grouping = @import("grouping.zig");
const punctuation = @import("punctiation.zig");

pub const TokenType = token.TokenType;
pub const Token = token.Token;

/// Creates an array list of tokens. The caller is responsible of
/// calling `deinit` to free the array list
pub fn tokenize(input: []const u8, alloc: std.mem.Allocator) !std.ArrayList(Token) {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = std.ArrayList(Token).init(alloc);

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
        // attempt to lex a string
        else if (try string.lex(input, actual_next_pos)) |tuple| {
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
        // attempt to lex grouping signs
        else if (try grouping.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
        }
        // lex punctuation
        else if (try punctuation.lex(input, actual_next_pos)) |tuple| {
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

    return tokens;
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

test {
    std.testing.refAllDecls(@This());
}

test "should insert 1 item" {
    const input = "322";
    const arrl = try tokenize(input, std.testing.allocator);
    arrl.deinit();
}

test "should insert 2 item" {
    const input = "322 644";
    const arrl = try tokenize(input, std.testing.allocator);
    arrl.deinit();
}
