const std = @import("std");
const lexic = @import("lexic");
const expression = @import("./expression.zig");
const Token = lexic.Token;
const TokenType = lexic.TokenType;
const ParseError = @import("./types.zig").ParseError;

const Statement = union(enum) {
    VariableBinding: u8,
};

const VariableBinding = struct {
    is_mutable: bool,
    datatype: ?*Token,
    identifier: *Token,
    expression: expression.Expression,

    fn parse() !@This() {}
};

test {
    std.testing.refAllDecls(@This());
}
