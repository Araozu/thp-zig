pub const OpCode = enum(u8) {
    OP_RETURN = 0x00,

    /// <cons> idx
    ///
    /// Push a constant **index** onto the stack. Its always a u64.
    OP_CONSTANT = 0x02,

    // ====================
    //  Numeric opcodes
    // ====================
    // OP_ADD_I32 = 0x03,
    // OP_SUB_I32 = 0x04,
    // OP_NEGATE_I32 = 0x05,
    //
    // OP_ADD_U32 = 0x06,
    // OP_SUB_U32 = 0x07,
    //
    // OP_ADD_F32 = 0x08,
    // OP_SUB_F32 = 0x09,
    // OP_NEGATE_F32 = 0x0A,

    OP_ADD_I64 = 0x0B,
    OP_SUB_I64 = 0x0C,
    OP_NEGATE_I64 = 0x0D,

    OP_ADD_U64 = 0x0E,
    OP_SUB_U64 = 0x0F,

    OP_ADD_F64 = 0x10,
    OP_SUB_F64 = 0x11,
    OP_NEGATE_F64 = 0x12,
    // ====================
    //  end Numeric opcodes
    // ====================

    /// Prints the string currently at the top of the stack
    OP_PRINT = 0x13,

    /// String concatenation
    OP_CONCAT = 0x14,

    /// <ref> constant_idx:u8
    ///
    /// Reads the constant at `constant_idx`.
    /// Interprets it as a pointer to an Obj.
    /// Pushes the Obj onto the stack, as a Value.
    OP_REF = 0x15,

    /// Transformations to string
    OP_F64_TO_STRING = 0x16,
    OP_U64_TO_STRING = 0x17,

    /// Store to variable slot
    ///
    /// <op> <idx>
    OP_STORE = 0x18,
    /// Load from variable slot
    ///
    /// <op> <idx>
    OP_LOAD = 0x19,
};
