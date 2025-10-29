# The THP programming language

This is the source code for the THP programming language.
THP stands for "Typed Hypertext Preprocessor", and is a
functional first, strong, nominal, statically typed language
that compiles down to PHP.

It is completely written in Zig, it is being rewritten from Rust.
There is documentation and a WIP spec at
[https://thp-lang.org](https://thp-lang.org).

## Install

This software is nowhere near to be useful, but hey, it runs... some of the time.

This program has exactly 1 dependency: the zig standard library, and has 2 binaries:

- The main `thp` compiler. THP source code comes in, THP bytecode comes out.
- The thp vm. It reads a bytecode file & executes it.


- Install [the Zig programming language](https://ziglang.org/).
- Run `zig build -Doptimize=ReleaseFast`
- The binary will be located at `zig-out/bin/thp`
- Profit


## Usage

Again, nowhere near to be useful.

### Write source code

As of v0.0.2 the compiler is able to compile a print of exactly 1 float number.

```thp
val _ = print(125.322)
val __ = print(644.0)
```

### Compile

Run `zig build run -- c /path/to/thp/source/code > out.thpb`, where `out.thpb` is
the file to write the bytecode to. Right now the compiler just writes bytes to
stdout.

### Run

Load & execute the bytecode with `zig build run-vm -- out.thpb`. Your floats
should be printed.

