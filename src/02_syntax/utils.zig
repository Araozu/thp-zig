const std = @import("std");
const lexic = @import("lexic");

/// Expects that the given token `t` has type `value`.
/// If it fails returns `error.Unmatched`, otherwise
/// returns the same token passed (`t`)
pub inline fn expect_token_type(comptime value: lexic.TokenType, t: *lexic.Token) error{Unmatched}!*lexic.Token {
    if (t.token_type == value) {
        return t;
    } else {
        return error.Unmatched;
    }
}

pub inline fn expect_operator(comptime value: []const u8, t: *lexic.Token) error{Unmatched}!*lexic.Token {
    if (t.token_type == lexic.TokenType.Operator and std.mem.eql(u8, value, t.value)) {
        return t;
    } else {
        return error.Unmatched;
    }
}
