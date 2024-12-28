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

const errors = @import("errors");

pub const TokenType = token.TokenType;
pub const Token = token.Token;
const LexError = token.LexError;

/// Creates an array list of tokens. The caller is responsible of
/// calling `deinit` to free the array list
///
/// Also takes an arraylist of errors. This will be populated if any errors are
/// found while lexing. The caller is responsible for freeing it.
pub fn tokenize(
    input: []const u8,
    alloc: std.mem.Allocator,
    err_arrl: *std.ArrayList(errors.ErrorData),
) !std.ArrayList(Token) {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = std.ArrayList(Token).init(alloc);
    errdefer tokens.deinit();

    while (current_pos < input_len) {
        const actual_next_pos = ignore_whitespace(input, current_pos);
        assert(current_pos <= actual_next_pos);

        // if after processing whitespace we reach eof, exit
        if (actual_next_pos == input_len) {
            break;
        }

        // attempt to lex a number
        var current_error: errors.ErrorData = undefined;
        const number_lex = number.lex(input, input_len, actual_next_pos, &current_error, alloc) catch |e| switch (e) {
            // recoverable errors
            LexError.Incomplete => {
                // add to list of errors
                try err_arrl.append(current_error);

                // ignore everything until whitespace and loop
                current_pos = ignore_until_whitespace(input, actual_next_pos);
                continue;
            },
            // just throw unrecoverable errors
            else => return e,
        };
        if (number_lex) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
            continue;
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
        else {
            // Create an error "nothing matched" and continue lexing
            // after the whitespace
            try current_error.init("Unrecognized character", actual_next_pos, actual_next_pos + 1, alloc);
            try err_arrl.append(current_error);
            current_pos = ignore_until_whitespace(input, actual_next_pos);
            continue;
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

/// Ignores all chars on `input` since `start`
/// and returns the position where the first whitespace/newline
/// is found.
inline fn ignore_until_whitespace(input: []const u8, start: usize) usize {
    const cap = input.len;
    var pos = start;

    while (pos < cap and (input[pos] != ' ' and input[pos] != '\t')) {
        pos += 1;
    }

    return pos;
}

test {
    std.testing.refAllDecls(@This());
}

test "should insert 1 item" {
    const input = "322";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const arrl = try tokenize(input, std.testing.allocator, &error_list);
    arrl.deinit();
}

test "should insert 2 item" {
    const input = "322 644";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const arrl = try tokenize(input, std.testing.allocator, &error_list);
    arrl.deinit();
}

test "should insert an item, fail, and not leak" {
    const input = "322 \"hello";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const arrl = tokenize(input, std.testing.allocator, &error_list) catch |e| switch (e) {
        error.IncompleteString => {
            return;
        },
        else => {
            try std.testing.expect(false);
            return;
        },
    };
    try std.testing.expect(false);
    arrl.deinit();
}

test "shouldnt leak" {
    const input = "";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    const arrl = try tokenize(input, std.testing.allocator, &error_list);
    arrl.deinit();
}

test "should handle recoverable errors" {
    const input = "322 0b 644";
    var error_list = std.ArrayList(errors.ErrorData).init(std.testing.allocator);
    defer error_list.deinit();
    defer for (error_list.items) |*err| err.deinit();
    const arrl = try tokenize(input, std.testing.allocator, &error_list);
    defer arrl.deinit();

    try std.testing.expectEqual(@as(usize, 1), error_list.items.len);
    try std.testing.expectEqual(@as(usize, 2), arrl.items.len);

    try std.testing.expectEqualStrings("Incomplete number", error_list.items[0].reason);
    try std.testing.expectEqual(@as(usize, 4), error_list.items[0].start_position);
    try std.testing.expectEqual(@as(usize, 6), error_list.items[0].end_position);
}
