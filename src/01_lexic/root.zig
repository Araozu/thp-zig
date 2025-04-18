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

const context = @import("context");

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
    allocator: std.mem.Allocator,
    err_ctx: *context.ErrorContext,
) !std.ArrayList(Token) {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = std.ArrayList(Token).init(allocator);
    errdefer tokens.deinit();

    while (current_pos < input_len) {
        const actual_next_pos = ignore_whitespace(input, current_pos);
        assert(current_pos <= actual_next_pos);

        // if after processing whitespace we reach eof, exit
        if (actual_next_pos == input_len) {
            break;
        }

        // attempt to lex a number
        // the lexer adds any errors to the context as neccesary
        const number_lex = number.lex(input, input_len, actual_next_pos, err_ctx) catch |e| switch (e) {
            // recoverable errors
            LexError.Incomplete, LexError.LeadingZero, LexError.IncompleteFloatingNumber, LexError.IncompleteScientificNumber => {
                // move to next syncronization point (whitespace) to recover lexing
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

        // attempt to lex an identifier. identifier parsing has no errors
        if (try identifier.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
            continue;
        }

        // attempt to lex a string
        const str_lex = string.lex(input, actual_next_pos, err_ctx) catch |e| switch (e) {
            LexError.IncompleteString => {
                current_pos = ignore_until_whitespace(input, actual_next_pos);
                continue;
            },
            else => return e,
        };
        if (str_lex) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
            continue;
        }

        // attempt to lex a datatype
        if (try datatype.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
            continue;
        }

        // attempt to lex a comment
        const comment_lex = comment.lex(input, actual_next_pos, err_ctx) catch |e| switch (e) {
            LexError.CRLF => {
                current_pos = ignore_until_whitespace(input, actual_next_pos);
                continue;
            },
            else => return e,
        };
        if (comment_lex) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(t);
            continue;
        }

        // attempt to lex an operator
        if (try operator.lex(input, actual_next_pos)) |tuple| {
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
            _ = try err_ctx.create_and_append_error("Unrecognized character", actual_next_pos, actual_next_pos + 1);
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
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322";
    const arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit();
}

test "should insert 2 item" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322 644";
    const arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit();
}

test "should insert an item, fail, and not leak" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322 \"hello";

    const arrl = tokenize(input, std.testing.allocator, &ctx) catch |e| switch (e) {
        else => {
            try std.testing.expect(false);
            return;
        },
    };
    defer arrl.deinit();
}

test "shouldnt leak" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "";
    const arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit();
}

test "should handle recoverable errors" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "322 0b 644";
    const arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit();

    try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 2), arrl.items.len);

    try std.testing.expectEqualStrings("Incomplete number", ctx.errors.items[0].reason);
    try std.testing.expectEqual(@as(usize, 4), ctx.errors.items[0].start_position);
    try std.testing.expectEqual(@as(usize, 6), ctx.errors.items[0].end_position);
}

test "lexer fuzzing" {
    return std.testing.fuzz({}, fuzz_impl, .{});
}

fn fuzz_impl(ctx: void, source: []const u8) anyerror!void {
    _ = ctx;
    const input = try std.testing.allocator.dupeZ(u8, source);
    defer std.testing.allocator.free(input);

    var err_ctx = context.ErrorContext.init(std.testing.allocator);
    defer err_ctx.deinit();

    const arrl = try tokenize(input, std.testing.allocator, &err_ctx);
    defer arrl.deinit();
}
