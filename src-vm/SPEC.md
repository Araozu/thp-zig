# The THP Virtual Machine

Heavily based on Crafting Interpreters lox vm.

## Bytecode specification

1-byte wide instructions.

## Bytecode format

Always uses BIG endian.

- First 4 bytes: "0x54 0x48 0x50 0x21" (THP!)
- Next 4 bytes(u32): len of the constants section
- Next n bytes: constants section
- Next bytes: bytecode

Bytecode **MUST** always end with 0x00 (OP_RETURN).

