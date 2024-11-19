const std = @import("std");
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

/// Lexes a datatype
pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    const cap = input.len;
    var final_pos = start;

    if (start >= cap) {
        return null;
    }

    // lex lowercase or underscore
    if (!utils.is_lowercase_underscore(input[start])) {
        return null;
    }
    final_pos += 1;

    // lex many lowercase/uppercase/underscore/number
    if (utils.lex_many(utils.is_identifier_char, input, final_pos)) |new_pos| {
        final_pos = new_pos;
    }

    return .{
        Token.init(input[start..final_pos], TokenType.Identifier, start),
        final_pos,
    };
}

test "should lex single letter" {
    const input = "a";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("a", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single underscore" {
    const input = "_";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("_", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex identifier 1" {
    const input = "abc";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("abc", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex identifier 2" {
    const input = "snake_case";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("snake_case", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex identifier 3" {
    const input = "camelCase";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("camelCase", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex identifier 4" {
    const input = "identifier_number_3";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("identifier_number_3", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt lex datatype" {
    const input = "MyDatatype";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}
