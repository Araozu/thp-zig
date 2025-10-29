# The THP Virtual Machine

Heavily based on Crafting Interpreters lox vm.

## Bytecode specification

1-byte wide instructions.

## Bytecode format

- First 4 bytes: "0x54 0x48 0x50 0x21" (THP!)

- Next 4 bytes: len of the constants section, in bytes (n)
- Next n bytes: constants section
- Next bytes: bytecode


