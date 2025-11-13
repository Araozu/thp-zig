const std = @import("std");
const assert = std.debug.assert;
const token = @import("./token.zig");
const utils = @import("./utils.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const LexError = token.LexError;
const LexReturn = token.LexReturn;

// lex an operator
pub fn lex(input: []const u8, start: usize) LexError!?LexReturn {
    const cap = input.len;
    assert(start < cap);

    // lex operator
    if (utils.lex_many_1(utils.is_operator_char, input, start)) |final_pos| {
        return .{
            Token.init(input[start..final_pos], TokenType.Operator, start),
            final_pos,
        };
    }
    // no operator found
    else {
        return null;
    }
}

test "should lex single operator" {
    const input = "=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("=", t.value);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex operator of len 2" {
    const input = "+=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+=", t.value);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex operator of len 3" {
    const input = " >>= ";
    const output = try lex(input, 1);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(">>=", t.value);
        try std.testing.expectEqual(4, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should not lex something else" {
    const input = "322";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

// ============================================================================
// Single Character Operator Tests
// ============================================================================

test "should lex single plus operator" {
    const input = "+";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single minus operator" {
    const input = "-";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("-", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single asterisk operator" {
    const input = "*";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("*", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single slash operator" {
    const input = "/";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("/", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single equals operator" {
    const input = "=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single exclamation operator" {
    const input = "!";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("!", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single pipe operator" {
    const input = "|";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("|", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single at operator" {
    const input = "@";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("@", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single hash operator" {
    const input = "#";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("#", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single dollar operator" {
    const input = "$";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("$", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single tilde operator" {
    const input = "~";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("~", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single percent operator" {
    const input = "%";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("%", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single ampersand operator" {
    const input = "&";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("&", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single question operator" {
    const input = "?";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("?", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single less-than operator" {
    const input = "<";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("<", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single greater-than operator" {
    const input = ">";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(">", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single caret operator" {
    const input = "^";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("^", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single dot operator" {
    const input = ".";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(".", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex single colon operator" {
    const input = ":";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(":", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(1, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Two Character Operator Tests
// ============================================================================

test "should lex double equals operator" {
    const input = "==";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("==", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex not equals operator" {
    const input = "!=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("!=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex less than or equal operator" {
    const input = "<=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("<=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex greater than or equal operator" {
    const input = ">=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(">=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex logical and operator" {
    const input = "&&";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("&&", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex logical or operator" {
    const input = "||";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("||", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex increment operator" {
    const input = "++";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("++", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex decrement operator" {
    const input = "--";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("--", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex minus equals operator" {
    const input = "-=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("-=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex multiply equals operator" {
    const input = "*=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("*=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex divide equals operator" {
    const input = "/=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("/=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex modulo equals operator" {
    const input = "%=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("%=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex bitwise and equals operator" {
    const input = "&=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("&=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex bitwise or equals operator" {
    const input = "|=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("|=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex bitwise xor equals operator" {
    const input = "^=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("^=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex left shift operator" {
    const input = "<<";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("<<", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex right shift operator" {
    const input = ">>";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep(">>", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex arrow operator" {
    const input = "->";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("->", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex double colon operator" {
    const input = "::";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("::", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex double dot operator" {
    const input = "..";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("..", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Three Character Operator Tests
// ============================================================================

test "should lex left shift equals operator" {
    const input = "<<=";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("<<=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex ellipsis operator" {
    const input = "...";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("...", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Positioning
// ============================================================================

test "should lex operator at end of string" {
    const input = "value+";
    const output = try lex(input, 5);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex operator in middle of string" {
    const input = "a + b";
    const output = try lex(input, 2);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should track correct start position for operator" {
    const input = "    +=";
    const output = try lex(input, 4);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(@as(usize, 4), t.start_pos);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Mixed Characters
// ============================================================================

test "should stop operator at non-operator character" {
    const input = "+=abc";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should stop operator at digit" {
    const input = "==123";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("==", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should stop operator at whitespace" {
    const input = "++ ";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("++", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should stop operator at newline" {
    const input = "!=\n";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("!=", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(2, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Long Operator Sequences
// ============================================================================

test "should lex very long operator sequence" {
    const input = "::::::::";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("::::::::", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(8, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex mixed operator characters sequence" {
    const input = "+=-*/%";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+=-*/%", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(6, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Edge Case Tests - Special Combinations
// ============================================================================

test "should lex triple equals as one operator" {
    const input = "===";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("===", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(3, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

test "should lex all operator characters in sequence" {
    const input = "+-=*!/|@#$~%&?<>^.:";
    const output = try lex(input, 0);

    if (output) |tuple| {
        const t = tuple[0];
        try std.testing.expectEqualDeep("+-=*!/|@#$~%&?<>^.:", t.value);
        try std.testing.expectEqual(TokenType.Operator, t.token_type);
        try std.testing.expectEqual(19, tuple[1]);
    } else {
        try std.testing.expect(false);
    }
}

// ============================================================================
// Negative Tests - Non-operators
// ============================================================================

test "should not lex letter as operator" {
    const input = "abc";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex underscore as operator" {
    const input = "_test";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex paren as operator" {
    const input = "(";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex bracket as operator" {
    const input = "[";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex brace as operator" {
    const input = "{";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}

test "should not lex comma as operator" {
    const input = ",";
    const output = try lex(input, 0);

    try std.testing.expect(output == null);
}
