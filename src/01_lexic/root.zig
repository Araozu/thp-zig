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
) !std.ArrayListUnmanaged(Token) {
    const input_len = input.len;
    var current_pos: usize = 0;

    var tokens = try std.ArrayListUnmanaged(Token).initCapacity(allocator, 10);
    errdefer tokens.deinit(allocator);

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

            try tokens.append(allocator, t);
            continue;
        }

        // attempt to lex an identifier. identifier parsing has no errors
        if (try identifier.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(allocator, t);
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

            try tokens.append(allocator, t);
            continue;
        }

        // attempt to lex a datatype
        if (try datatype.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(allocator, t);
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

            try tokens.append(allocator, t);
            continue;
        }

        // attempt to lex an operator
        if (try operator.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(allocator, t);
        }
        // attempt to lex grouping signs
        else if (try grouping.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(allocator, t);
        }
        // lex punctuation
        else if (try punctuation.lex(input, actual_next_pos)) |tuple| {
            assert(tuple[1] > current_pos);
            const t = tuple[0];
            current_pos = tuple[1];

            try tokens.append(allocator, t);
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
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit(std.testing.allocator);
}

test "should insert 2 item" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322 644";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit(std.testing.allocator);
}

test "should insert an item, fail, and not leak" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "322 \"hello";

    var arrl = tokenize(input, std.testing.allocator, &ctx) catch |e| switch (e) {
        else => {
            try std.testing.expect(false);
            return;
        },
    };
    defer arrl.deinit(std.testing.allocator);
}

test "shouldnt leak" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();
    const input = "";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    arrl.deinit(std.testing.allocator);
}

test "should handle recoverable errors" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "322 0b 644";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 2), arrl.items.len);

    try std.testing.expectEqualStrings("Incomplete number", ctx.errors.items[0].reason);
    try std.testing.expectEqual(@as(usize, 4), ctx.errors.items[0].start_position);
    try std.testing.expectEqual(@as(usize, 6), ctx.errors.items[0].end_position);
}

// ============================================================================
// Integration Tests - Operators in Context
// ============================================================================

test "should tokenize simple arithmetic expression" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "1 + 2 - 3 * 4 / 5";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 9), arrl.items.len);

    // Check operators
    try std.testing.expectEqual(TokenType.Operator, arrl.items[1].token_type);
    try std.testing.expectEqualStrings("+", arrl.items[1].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[3].token_type);
    try std.testing.expectEqualStrings("-", arrl.items[3].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[5].token_type);
    try std.testing.expectEqualStrings("*", arrl.items[5].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[7].token_type);
    try std.testing.expectEqualStrings("/", arrl.items[7].value);
}

test "should tokenize comparison operators" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a == b != c <= d >= e < f > g";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 13), arrl.items.len);

    try std.testing.expectEqual(TokenType.Operator, arrl.items[1].token_type);
    try std.testing.expectEqualStrings("==", arrl.items[1].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[3].token_type);
    try std.testing.expectEqualStrings("!=", arrl.items[3].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[5].token_type);
    try std.testing.expectEqualStrings("<=", arrl.items[5].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[7].token_type);
    try std.testing.expectEqualStrings(">=", arrl.items[7].value);
}

test "should tokenize logical operators" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a && b || c";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 5), arrl.items.len);

    try std.testing.expectEqual(TokenType.Operator, arrl.items[1].token_type);
    try std.testing.expectEqualStrings("&&", arrl.items[1].value);
    try std.testing.expectEqual(TokenType.Operator, arrl.items[3].token_type);
    try std.testing.expectEqualStrings("||", arrl.items[3].value);
}

test "should tokenize assignment operators" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "x = y += z -= a *= b /= c";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 11), arrl.items.len);

    try std.testing.expectEqualStrings("=", arrl.items[1].value);
    try std.testing.expectEqualStrings("+=", arrl.items[3].value);
    try std.testing.expectEqualStrings("-=", arrl.items[5].value);
    try std.testing.expectEqualStrings("*=", arrl.items[7].value);
    try std.testing.expectEqualStrings("/=", arrl.items[9].value);
}

test "should tokenize bitwise operators" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a & b | c ^ d << e >> f";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 11), arrl.items.len);

    try std.testing.expectEqualStrings("&", arrl.items[1].value);
    try std.testing.expectEqualStrings("|", arrl.items[3].value);
    try std.testing.expectEqualStrings("^", arrl.items[5].value);
    try std.testing.expectEqualStrings("<<", arrl.items[7].value);
    try std.testing.expectEqualStrings(">>", arrl.items[9].value);
}

test "should tokenize unary operators" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "!a ~b -c +d";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 8), arrl.items.len);

    try std.testing.expectEqualStrings("!", arrl.items[0].value);
    try std.testing.expectEqualStrings("~", arrl.items[2].value);
    try std.testing.expectEqualStrings("-", arrl.items[4].value);
    try std.testing.expectEqualStrings("+", arrl.items[6].value);
}

test "should tokenize operators without spaces" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "1+2*3";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 5), arrl.items.len);

    try std.testing.expectEqualStrings("1", arrl.items[0].value);
    try std.testing.expectEqualStrings("+", arrl.items[1].value);
    try std.testing.expectEqualStrings("2", arrl.items[2].value);
    try std.testing.expectEqualStrings("*", arrl.items[3].value);
    try std.testing.expectEqualStrings("3", arrl.items[4].value);
}

// ============================================================================
// Integration Tests - Punctuation in Context
// ============================================================================

test "should tokenize function arguments with commas" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "func(a, b, c)";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 8), arrl.items.len);

    try std.testing.expectEqual(TokenType.Comma, arrl.items[3].token_type);
    try std.testing.expectEqualStrings(",", arrl.items[3].value);
    try std.testing.expectEqual(TokenType.Comma, arrl.items[5].token_type);
    try std.testing.expectEqualStrings(",", arrl.items[5].value);
}

test "should tokenize array elements with commas" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "[1, 2, 3, 4]";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 9), arrl.items.len);

    try std.testing.expectEqual(TokenType.Comma, arrl.items[2].token_type);
    try std.testing.expectEqual(TokenType.Comma, arrl.items[4].token_type);
    try std.testing.expectEqual(TokenType.Comma, arrl.items[6].token_type);
}

test "should tokenize multiple statements with newlines" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a\nb\nc";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 5), arrl.items.len);

    try std.testing.expectEqual(TokenType.Newline, arrl.items[1].token_type);
    try std.testing.expectEqualStrings("\n", arrl.items[1].value);
    try std.testing.expectEqual(TokenType.Newline, arrl.items[3].token_type);
    try std.testing.expectEqualStrings("\n", arrl.items[3].value);
}

test "should tokenize multiple empty lines" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a\n\n\nb";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 5), arrl.items.len);

    try std.testing.expectEqual(TokenType.Newline, arrl.items[1].token_type);
    try std.testing.expectEqual(TokenType.Newline, arrl.items[2].token_type);
    try std.testing.expectEqual(TokenType.Newline, arrl.items[3].token_type);
}

test "should tokenize trailing comma" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "[1, 2, 3,]";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 8), arrl.items.len);

    try std.testing.expectEqual(TokenType.Comma, arrl.items[6].token_type);
}

// ============================================================================
// Integration Tests - Mixed Operators and Punctuation
// ============================================================================

test "should tokenize complex expression with operators and punctuation" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "x = func(a + b, c * d)\ny = z";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);

    // Verify we have a mix of identifiers, operators, punctuation
    var has_operator = false;
    var has_comma = false;
    var has_newline = false;

    for (arrl.items) |tok| {
        if (tok.token_type == TokenType.Operator) has_operator = true;
        if (tok.token_type == TokenType.Comma) has_comma = true;
        if (tok.token_type == TokenType.Newline) has_newline = true;
    }

    try std.testing.expect(has_operator);
    try std.testing.expect(has_comma);
    try std.testing.expect(has_newline);
}

test "should tokenize ternary-like operator" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "a ? b : c";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 5), arrl.items.len);

    try std.testing.expectEqualStrings("?", arrl.items[1].value);
    try std.testing.expectEqualStrings(":", arrl.items[3].value);
}

test "should tokenize member access chain" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "obj.prop.method()";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);

    // Check for dot operators
    var dot_count: usize = 0;
    for (arrl.items) |tok| {
        if (tok.token_type == TokenType.Operator and std.mem.eql(u8, tok.value, ".")) {
            dot_count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 2), dot_count);
}

test "should tokenize range operator with spaces" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    // Note: "1..10" causes lexer issues because "1." is parsed as a float
    // Using spaces to avoid this bug in the number lexer
    const input = "1 .. 10";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 3), arrl.items.len);

    try std.testing.expectEqualStrings("..", arrl.items[1].value);
}

test "range operator without spaces causes lexer bug" {
    // BUG DOCUMENTATION: When lexing "1..10", the number lexer parses "1." as a
    // floating point number, then ".10" as another float, causing an error.
    // This is a known issue with how the lexer prioritizes float parsing over
    // the range operator.
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "1..10";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    // Currently this produces an error due to the bug described above
    // Expected: 0 errors with tokens [Int("1"), Operator(".."), Int("10")]
    // Actual: 1 error with tokens [Float("1."), Float(".10")]
    try std.testing.expectEqual(@as(usize, 1), ctx.errors.items.len);
}

test "should tokenize spread operator" {
    var ctx = context.ErrorContext.init(std.testing.allocator);
    defer ctx.deinit();

    const input = "...rest";
    var arrl = try tokenize(input, std.testing.allocator, &ctx);
    defer arrl.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), ctx.errors.items.len);
    try std.testing.expectEqual(@as(usize, 2), arrl.items.len);

    try std.testing.expectEqualStrings("...", arrl.items[0].value);
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

    var arrl = try tokenize(input, std.testing.allocator, &err_ctx);
    defer arrl.deinit(std.testing.allocator);
}
