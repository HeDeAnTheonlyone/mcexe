# ⚠️This project is very early in development and very far from being finished⚠️



# mcexe
mcexe is a compiler that compiles minecraft datapacks and commands into real executable programs.<br>
It does that by interpreting different commands, for example `/give @s txt{CustomName:"test_file"}`, and generates zig code.<br>
In this case, the command would creates a `txt` file with the name `test_file` in the `current working directory`.<br>
It then compiles the generated zig file to the specified output file.<br>
Because it use Zig as intermediate language, it will have (nearly) all the capabilities of zig.



## Usage
 
1. (optional) Add the folder where you unzipped the files to your path environment variables for easier access to the mcexe.exe file. 
2.  Run mcexe.exe either directly in your datapack root directory without arguments or<br>run it from anywhere else with the `-path "path to your datapack"` arguments (It automatically recognize if it's an absolute or relative file path)
3. Retrieve your compiled program from the newly generated `out` folder in your datapack. (There will also be the interpreted .zig file, .obj object file, and if you're on windows a .pbd file)



## Currently Supported
- Commands:
  - say



## Will be unsupported in version 1.0.0
- multiline commands
- everything else than function files (advancements, predicates, loot tables, etc.)
