# ⚠️This project is very early in development and very far from being finished⚠️

![mcexe logo](https://github.com/HeDeAnTheonlyone/mcexe/blob/main/mcexe.png)<br>
*(lizard in German is pronounced like exe and it is written in Zig, which also has a lizard as mascot)*<br>
# mcexe
mcexe is a transpiler that converts minecraft datapacks and commands into real executable programs.<br>
It does that by interpreting different commands, for example `/give @s paper[minecraft:item_name="test_file"]`, and generates Zig code.<br>
In this case, the command would create a `txt` file with the name `test_file` in the `current working directory`.<br>
It then compiles the generated Zig file to the specified executable file.<br>
Because it uses Zig as intermediate language, it will have (nearly) all the capabilities of Zig.



## Usage
 
1. (optional) Add the folder where you unzipped the files to your path environment variables for easier access to the mcexe command. 
2.  Run mcexe either directly in your datapack root directory without arguments or<br>run it from anywhere else with the `-path "path/to/your/datapack"` arguments (It automatically recognizes if it's an absolute or relative file path)
3. Retrieve your compiled program from the newly generated `out` folder in your datapack. (There will also be subfolders that contain other files for internal stuff)



## Will be unsupported in version 1.0.0
- multiline commands
- everything else than function files (advancements, predicates, loot tables, etc.)

***

![mcexe logo](https://github.com/HeDeAnTheonlyone/mcexe/blob/main/mcexe_big.png)
