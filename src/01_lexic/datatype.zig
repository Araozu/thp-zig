const std = @import("std");
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

/// Lexes a Datatype
pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    const cap = input.len;
    var final_pos = start;

    if (start >= cap) {
        return null;
    }

    // lex uppercase
    if (!utils.is_uppercase(input[start])) {
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

test "should lex datatype" {
    const input = "MyType";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("MyType", t.value);
    } else {
        try std.testing.expect(false);
    }
}

test "shouldnt lex identifier" {
    const input = "myDatatype";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}
