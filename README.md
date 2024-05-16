# mcexe
mcexe is a compiler that compiles minecraft datapacks and commands into real executable programs.<br>
It does that by interpreting different commands, for example `/give @s txt{CustomName:"test_file"}`, and generates zig code.<br>
In this case, the command would creates a `txt` file with the name `test_file` in the `current working directory`.<br>
It then compiles the generated zig file to the specified output file.<br>
Because it use Zig as intermediate language, it will have (nearly) all the capabilities of zig.


### Unsupported in version 1.0.0
- multiline commands
- everything else than function files (advancements, predicates, loot tables, etc.)