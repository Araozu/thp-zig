const token = @import("./token.zig");
const LexError = token.LexError;
const LexReturn = token.LexReturn;

pub fn is_decimal_digit(c: u8) bool {
    return '0' <= c and c <= '9';
}

pub fn is_octal_digit(c: u8) bool {
    return '0' <= c and c <= '7';
}

pub fn is_binary_digit(c: u8) bool {
    return c == '0' or c == '1';
}

pub fn is_hex_digit(c: u8) bool {
    return ('0' <= c and c <= '9') or ('a' <= c and c <= 'f') or ('A' <= c and c <= 'F');
}

pub fn is_lowercase(c: u8) bool {
    return 'a' <= c and c <= 'z';
}

pub fn is_uppercase(c: u8) bool {
    return 'A' <= c and c <= 'Z';
}

pub fn is_lowercase_underscore(c: u8) bool {
    return c == '_' or ('a' <= c and c <= 'z');
}

/// identifier_letter = underscore | lowercase | uppercase | digit
pub fn is_identifier_char(c: u8) bool {
    return c == '_' or ('a' <= c and c <= 'z') or ('A' <= c and c <= 'Z') or ('0' <= c and c <= '9');
}

/// Runs a discriminator function at least once,
/// and returns the end position of the lex.
///
/// If there is no more input or the lexer does not match
/// at least once, returns null.
pub fn lex_many_1(
    comptime lex_fun: fn (c: u8) bool,
    input: []const u8,
    start: usize,
) usize {
    // assert that there is input left
    const cap = input.len;
    var current_pos = start;

    if (current_pos >= cap) {
        return null;
    }

    // run the lexer at least once
    if (!lex_fun(input[current_pos])) {
        return null;
    }
    current_pos += 1;

    // run the lexer many times
    while (current_pos < cap and lex_fun(input[current_pos])) {
        current_pos += 1;
    }

    return current_pos;
}

/// Runs a discriminator function zero, one or more times
/// and returns the end position of the lex.
///
/// If there is no more input or the lexer does not match
/// at least once, returns null.
pub fn lex_many(
    comptime lex_fun: fn (c: u8) bool,
    input: []const u8,
    start: usize,
) ?usize {
    // assert that there is input left
    const cap = input.len;
    var current_pos = start;

    if (current_pos >= cap) {
        return null;
    }

    // run the lexer many times
    while (current_pos < cap and lex_fun(input[current_pos])) {
        current_pos += 1;
    }

    return current_pos;
}
