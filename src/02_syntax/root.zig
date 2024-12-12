const std = @import("std");
const lexic = @import("lexic");
const expression = @import("./expression.zig");
const variable = @import("./variable.zig");
const types = @import("./types.zig");

const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = types.ParseError;

const Statement = union(enum) {
    VariableBinding: u8,

    fn parse(tokens: *const std.ArrayList(Token), pos: usize) ParseError!@This() {
        _ = tokens;
        _ = pos;
        return ParseError.Error;
    }
};

test {
    std.testing.refAllDecls(@This());
}
