# The THP programming language

THP is a statically typed, compiled programming language. Compiles to its
own bytecode format, and runs on its own VM.

There is documentation and a WIP spec at
[https://thp-lang.org](https://thp-lang.org).


## Install

This program has exactly 1 dependency: the zig standard library, and has 2 binaries:

- The main `thp` compiler. THP source code comes in, THP bytecode comes out.
- The thp vm. It reads a bytecode file & executes it.


- Install [the Zig programming language](https://ziglang.org/).
- Run `zig build -Doptimize=ReleaseFast`
- The binary will be located at `zig-out/bin/thp`
- Profit


## Usage


### Write source code

As of v0.0.4 the compiler is able to do:
- Basic f64/u64 arithmetic
- Print strings & numbers
- Declare & use variables

```thp
var name = "John"
print("Hello, " + name + "!")
```


### Compile to file

Run `zig build run -- c /path/to/thp/source/code > out`, where `out` is
the file to write the bytecode to. Right now the compiler just writes bytes to
stdout.


### Run bytecode

Load & execute the bytecode with `zig build run-vm -- out`. Your floats
should be printed.


### Compile & run in one command

Run `zig build run -- run /path/to/thp/source/code`. It will compile & run
the code in one command.


## Contributing

### Naming conventions

- When importing modules, use `m_<module-name>`: `const m_parser = @import("./parser.zig");`
- Variables that hold a token have a `tok_` prefix: `const tok_number = ...`
- Variables that hold a type have a `t_` prefix: `const t_number = ...`
- Inside structs, the reference to self is always named `self`, and a helper const
  is created: `const Self = @This();`



