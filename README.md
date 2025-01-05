# The THP programming language

This is the source code for the THP programming language.
THP stands for "Typed Hypertext Preprocessor", and is a
functional first, strong, nominal, statically typed language
that compiles down to PHP.

It is completely written in Zig, it is being rewritten from Rust.
There is documentation and a WIP spec at
[https://thp-lang.org](https://thp-lang.org).

## Install

This software is nowhere near to be useful.

This program has exactly 1 dependency: the zig standard library.

- Install [the Zig programming language](https://ziglang.org/).
- Run `zig build -Doptimize=ReleaseFast`
- The binary will be located at `zig-out/bin/thp`
- Profit




