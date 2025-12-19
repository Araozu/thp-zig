# The THP Virtual Machine

Heavily based on Crafting Interpreters lox vm & the Common Language Infrastructure (CLI) specification.

## Bytecode specification

1-byte wide instructions.

## Bytecode format

Always uses BIG endian.

- First 4 bytes: "0x54 0x48 0x50 0x21" (THP!)

- Next 4 bytes(u32): len of the constants section
- Next n bytes: constants section

- Next 4 bytes(u32): len of the raw bytes section
- Next n bytes: raw bytes section

- Next bytes: bytecode

Bytecode **MUST** always end with 0x00 (OP_RETURN).


## Constant pool format

The constant pool is an array of `u64` entries.
The bytecode instructions load a single constant
and interpret it. The VM trusts the bytecode to
ensure that the correct type is loaded, and matches
the semantics of the language.


## Raw bytes section

Inside the raw bytes section, arbitrary data can be stored, following the format:

- First 4 bytes(u32): len of the next bytes section
- Next n bytes: raw bytes section

Multiple of these tuples are stored back to back.



## Bytecode behaviour

```zig
pub const OpCode = enum(u8) {
    OP_RETURN = 0x00,
    OP_PRINT_F64 = 0x01,
    OP_CONSTANT = 0x02,
    OP_ADD_F64 = 0x03,
    OP_NEGATE_F64 = 0x04,
    OP_SUB_F64 = 0x05,
    OP_ADD_U64 = 0x07,
    OP_SUB_U64 = 0x08,
    OP_PRINT_CONST = 0x09,
    OP_CONCAT = 0x0A,
};
```

OP_RETURN
    : Stops execution of the bytecode.

OP_PRINT_F64
    : Pops a value off the stack, interprets it as f64, and prints it.

OP_CONSTANT = 0x02,
    : Reads the byte pointed by ip, as `i`.
      Then reads the `i`th constant from the constant pool.
      Then pushes it onto the stack.

OP_ADD_F64 = 0x03,
    : Pops two values off the stack, interprets them as f64,
      adds them, and pushes the result back onto the stack.

OP_NEGATE_F64 = 0x04,
    : Pops a value off the stack, interprets it as f64,
      negates it, and pushes the result back onto the stack.

OP_SUB_F64 = 0x05,
    : Like OP_ADD_F64 but for subtraction.

OP_ADD_U64 = 0x07,
    : Like OP_ADD_F64 but for u64.

OP_SUB_U64 = 0x08,
    : Like OP_SUB_U64 but for u64.

OP_PRINT_CONST = 0x09,
    : Pops `offset` as `usize`.
      Pops `len` as `usize`.
      Reads `len` bytes from the constant pool starting at `offset`.
      Prints those bytes with a newline.

OP_CONCAT = 0x0A,
    : 




