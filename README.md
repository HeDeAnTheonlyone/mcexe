# ⚠️This project is early in development⚠️

![mcexe logo](/assest/mcexe.png)<br>
*(lizard in German is pronounced like exe and it is written in Zig, which has a lizard as mascot)*<br>

# What is mcexe?
mcexe is a compiler that converts minecraft datapacks and commands into real executable programs. Each command and other datapack object will get be treated as something typical in other programming languages (ex. Entities are files/streams/processes. Blocks represent memory). The translation of all those objects is not complete and subject to change.<br>

This is a rewrite with a completely different approach than the original (transpiler/compiler amalgamation with a horribly primitive parser).

> The rewrite uses [re2zig (re2c)](https://re2c.org/manual/manual_zig.html) for lexer generation and [tree sitter](https://tree-sitter.github.io/tree-sitter/index.html) for parser generation.

***

![mcexe logo](/assest/mcexe_big.png)
