# mcexe
mcexe is a compiler that compiles minecraft datapacks and commands into real executable programs.
It does that by interpreting different commands, like `/give @s txt{CustomName:"test_file"}`, and generates zig code that creates a `txt` file with the name `test_file` in the `current working directory`. It then compiles the generated zig file to the specified output file.
Because it use Zig as intermediate language, it will have (nearly) all the capabilities of zig.


### Unsupported in version 1.0.0
- multiline commands
- everything else than function files (advancements, predicates, loot tables, etc.)