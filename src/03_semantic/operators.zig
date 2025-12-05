const std = @import("std");
const m_types = @import("types.zig");

const Type = m_types.Type;

pub const OperatorSignature = struct {
    left: Type,
    right: Type,
    result: Type,
};

const plus_signatures = [_]OperatorSignature{
    .{ .left = .F64, .right = .F64, .result = .F64 },
    .{ .left = .I64, .right = .I64, .result = .I64 },
};

const minus_signatures = [_]OperatorSignature{
    .{ .left = .F64, .right = .F64, .result = .F64 },
    .{ .left = .I64, .right = .I64, .result = .I64 },
};

pub fn resolve_binary_operator(operator: []const u8, left: Type, right: Type) ?OperatorSignature {
    const signatures: []const OperatorSignature =
        if (std.mem.eql(u8, operator, "+")) &plus_signatures else if (std.mem.eql(u8, operator, "-")) &minus_signatures else return null;

    for (signatures) |signature| {
        if (signature.left.eql(&left) and signature.right.eql(&right)) {
            return signature;
        }
    }

    return null;
}
