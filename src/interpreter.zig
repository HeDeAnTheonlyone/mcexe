
const std = @import("std");
const manager = @import("manager.zig");
const f_collector = @import("util/file_collector.zig");
const parse_helper = @import("util/parse_helper.zig");
const array = @import("util/array.zig");

const DatapackErrors = parse_helper.DatapackErrors;
const getPrimaryCmd = parse_helper.getPrimaryCmd;
const getNextArgument = parse_helper.getNextArgument;
const getDataValue = parse_helper.getDataValue;
const removeNamespaceOrReturn = parse_helper.removeNamespaceOrReturn;
const Selector = parse_helper.Selector;
const Coordinates = parse_helper.Coordinates;
const Target = parse_helper.Target;
const Storage = parse_helper.Storage;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;



pub var status: Status = undefined;

const Status = struct {
    allocator: std.mem.Allocator,
    imports: ArrayList([]const u8),
    function_stack: ArrayList([]const u8),
    function_map: StringHashMap(InterpretedFunction),
    current_function: *InterpretedFunction,
    current_line: usize = 0,
    var_count: usize = 0,
    entity_map: StringHashMap(Entity),

    fn init(allocator: std.mem.Allocator) !Status {
        return Status {
            .allocator = allocator,
            .imports = ArrayList([]const u8).init(allocator),
            .function_stack = ArrayList([]const u8).init(allocator),
            .function_map = StringHashMap(InterpretedFunction).init(allocator),
            .current_function = undefined,
            .entity_map = StringHashMap(Entity).init(allocator),
        };
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.function_stack.deinit();
        self.function_map.deinit();
        self.entity_map.deinit();
    }

    /// Creates a new Function entry if it doesn't already exist, puts it on top of the functions stack and sets it as current function.
    fn createNewFunction(self: *Status, name: []const u8) !void {        
        if (self.function_map.contains(name)) return;

        try self.function_stack.append(name);
        try self.function_map.put(name, InterpretedFunction.init(self.allocator, name));

        status.updateCurrentFunction();
    }

    fn finishCurrentFunction(self: *Status) void {
        _ = self.function_stack.pop();

        status.updateCurrentFunction();
    }

    fn updateCurrentFunction(self: *Status) void {
        if (self.function_stack.items.len == 0) {
            self.current_function = undefined;
        }
        else self.current_function = self.function_map.getPtr(self.function_stack.getLast()).?;
    }

    /// Returns a new variable name to use in the interpreted code. It starts with 1 and counts up for each new variable. The returned name is `_<count>`.
    fn createNextVariableName(self: *Status) ![]const u8 {
        self.var_count += 1;
        return try std.fmt.allocPrint(self.allocator, "_{d}", .{self.var_count});
    }

    /// Appends an import, if it doesn't already exists. Imports are written to the file first.
    fn addImport(self: *Status, import_code: []const u8) !void {
        if (array.contains([]const u8, self.imports.items, import_code) == null) {
            try self.imports.append(import_code);
        }
    }

    fn spawnEntity(self: *Status, entity: Entity) !void {
        if (self.entity_map.contains(entity.uuid)) return DatapackErrors.EntityAlreadyExists;
        try self.entity_map.put(entity.uuid, entity);
    }

    // TODO
    // fn killEntity(self: *Status, entity: Entity) !void {

    // }

    /// Generates the output files and writes the interpreted code to it.
    pub fn flushCode(self: *Status, pack_path: []const u8, load_function_names: std.ArrayList([]const u8)) !void {
        const file = try generateOutFiles(self.allocator, pack_path);
        defer file.close();

        // Imports
        _ = try file.write("const std = @import(\"std\");\n");
        _ = try file.write("const interpret = @import(\"interpretation.zig\");\n");
        for (self.imports.items) |import| {
            _ = try file.write(import);
            _ = try file.write("\n");
        }
        //

        // All Funtions
        _ = try file.write("\n\n\npub fn main() !void {\n");
        for (load_function_names.items) |function_name| {
            _ = try file.write("_ = try ");
            _ = try file.write(function_name);
            _ = try file.write("();\n");
        }
        _ = try file.write("\nstd.debug.print(\"\\nConsole closes in 5 seconds.\", .{});\n");
        _ = try file.write("std.time.sleep(5 * std.time.ns_per_s);\n}\n\n\n\n");

        var function_iterator = self.function_map.valueIterator();
        while (function_iterator.next()) |func| {

            _ = try file.write("fn ");
            _ = try file.write(func.name);
            _ = try file.write("() !");
            _ = try file.write(if (func.returns) "i32" else "void");
            _ = try file.write(" {\n");

            for (func.top_vars.items) |top_var| {
                _ = try file.write(top_var);
            }
            _ = try file.write("\n");
            _ = try file.write(func.code.items);
            _ = try file.write("}\n\n");

            func.deinit();
        }
    }
};

pub fn initInterpreterStatus(allocator: std.mem.Allocator) !void {
    status = try Status.init(allocator);
}

pub fn deinitInterpreterStatus() void {
    status.deinit();
}



const InterpretedFunction = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    returns: bool = false,
    top_vars: ArrayList([]const u8),
    code: ArrayList(u8),

    fn init(allocator: std.mem.Allocator, name: []const u8) InterpretedFunction {
        return InterpretedFunction {
            .allocator = allocator,
            .name = name,
            .top_vars = ArrayList([]const u8).init(allocator),
            .code = ArrayList(u8).init(allocator)
        };
    }

    fn deinit(self: *InterpretedFunction) void {
        self.allocator.free(self.name); // The memory for name was allocated by `file_collector.Function`
        self.top_vars.deinit();
        self.code.deinit();
    }

    fn addTopVar(self: *InterpretedFunction, top_var: []const u8) !void {
        if (array.contains([]const u8, self.top_vars.items, top_var) == null) {
            try self.top_vars.append(top_var);
        }
    }

    fn addCode(self: *InterpretedFunction, code: []const u8) !void {
        try self.code.appendSlice(code);
        try self.code.append('\n');
    }
};



/// Generates the build.zig, copies the interpretation function file, and generateds the interpreted Zig file.
fn generateOutFiles(allocator: std.mem.Allocator, pack_path: []const u8) !std.fs.File {
    const namespace = namespace_blk: {
        var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
        break :namespace_blk path_iter.first();
    };

    var out_dir = out_dir_blk: {
        var pack_dir = try std.fs.openDirAbsolute(pack_path, .{});
        defer pack_dir.close();
        break :out_dir_blk try std.fs.Dir.makeOpenPath(pack_dir, "out/mcexe-out", .{});
    };
    defer out_dir.close();

    // copy interpreter.zig
    const lib_source_path = blk: {
        const parts = [2][]const u8{
            manager.settings.exe_dir_path,
            "/interpretation.zig"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };

    const lib_target_path = blk: {
        const dir = try out_dir.realpathAlloc(allocator, "");
        defer allocator.free(dir);

        const parts = [2][]const u8{
            dir,
            "/interpretation.zig"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    
    try std.fs.copyFileAbsolute(lib_source_path, lib_target_path, .{});
    allocator.free(lib_source_path);
    allocator.free(lib_target_path);

    // generate build.zig
    const build_file = try out_dir.createFile("build.zig", .{});
    defer build_file.close();

    const build_code = blk: {
        const parts = [5][]const u8{
            \\const std = @import("std");
            \\
            \\pub fn build(b: *std.Build) void {
            \\   const exe = b.addExecutable(.{
            \\      .name = "
            ,namespace,\\",
            \\      .root_source_file = b.path("
            ,namespace,\\.zig"),
            \\      .target = b.standardTargetOptions(.{}),
            \\      .optimize = b.standardOptimizeOption(.{}),
            \\   });
            \\   b.installArtifact(exe);
            \\}
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    _ = try build_file.writeAll(build_code);
    allocator.free(build_code);

    // creat and return empty interpretation file
    const out_file_name = blk: {
        const parts = [2][]const u8{
            namespace,
            ".zig"
        };        
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(out_file_name);

    return try out_dir.createFile(out_file_name, .{});
}


pub fn evalFunction(func: *f_collector.Function) !void {
    try status.createNewFunction(func.name);
    defer status.finishCurrentFunction();

    evalCmd(func.commands.first()) catch |err| outputErr(func, err);
    
    while (func.commands.next()) |cmd| : (func.current_line += 1) {
        evalCmd(cmd) catch |err| {
            outputErr(func, err);
        };
    }
}

fn outputErr(func: *f_collector.Function, err: AllErrors) void {
            // TODO stop ignoring and hiding all the leaked memory on error!
    std.log.err("\x1B[31mCommand in function '{s}' at line {d} failed to transpile with the error: {any}\x1B[0m", .{func.path, func.current_line, err});
    std.process.exit(1);
}



const Commands = parse_helper.Commands;

fn evalCmd(command: []const u8) !void {
    const primary_cmd = getPrimaryCmd(command) orelse return;
    const context_index = primary_cmd.len + 1;

    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .function => try function(command[context_index..]),
        .say => try say(command[context_index..]),
        .give => try give(command[context_index..]),
        .clear => try clear(command[context_index..]),
        .summon => try summon(command[context_index..]),
        .kill => try kill(command[context_index..]),
        // .data => try data(command[context_index..]),
        else => {
            return DatapackErrors.UnknownCommand;
        }
    }
}


// From here on downwards are all the functions that process and translate minecraft commands
const StdErrors = error {
    OutOfMemory,
    FileNotFound,
    AccessDenied,
    NameTooLong,
    NotDir,
    SymLinkLoop,
    InputOutput,
    FileTooBig,
    IsDir,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
    NoSpaceLeft,
    BadPathName,
    DeviceBusy,
    SharingViolation,
    PipeBusy,
    InvalidWtf8,
    NetworkNotFound,
    PathAlreadyExists,
    AntivirusInterference,
    Unexpected,
    InvalidUtf8,
    FileLocksNotSupported,
    FileBusy,
    WouldBlock,
    OperationAborted,
    BrokenPipe,
    ConnectionResetByPeer,
    ConnectionTimedOut,
    NotOpenForReading,
    SocketNotConnected,
    StreamTooLong
};

const AllErrors = StdErrors || DatapackErrors;

fn function(context: []const u8) AllErrors!void {
    var context_index: usize = 0;
    const function_path = getNextArgument(context, &context_index, ' ').?;

    var func = try f_collector.Function.init(status.allocator, manager.settings.path, function_path);
    defer func.deinit();

    const code = blk: {
        const parts = [3][]const u8{
            "_ = try ",
            func.name,
            "();"
        };
        break :blk try std.mem.concat(status.allocator, u8, &parts);
    };
    try status.current_function.addCode(code);
    status.allocator.free(code);

    try evalFunction(&func);
}



fn say(context: []const u8) !void {    
    try status.current_function.addTopVar("const stdout = std.io.getStdOut();");

    const code = blk: {
        const parts = [3][]const u8{
            "_ = try stdout.write(\"",
            context,
            "\\n\");"
        };
        break :blk try std.mem.concat(status.allocator, u8, &parts);
    };
    defer status.allocator.free(code);

    try status.current_function.addCode(code);
}



// fn tellraw(msg: []const u8) !void {
// }



const FileInfo = parse_helper.FileInfo;

fn give(context: []const u8) !void {
    const file_info = FileInfo.parse(context);

    const code = blk: {
        const parts = [9][]const u8{
            "try interpret.mkFile(",
            "\"",
            file_info.path,
            "\",\"",
            file_info.name,
            file_info.extension,
            "\",\"",
            file_info.data,
            "\");"
        };
        break :blk try std.mem.concat(status.allocator, u8, &parts);
    };
    defer status.allocator.free(code);

    try status.current_function.addCode(code);
}

fn clear(context: []const u8) !void {
    const file_info = FileInfo.parse(context);

    const code = blk: {
        const parts = [9][]const u8{
            "try interpret.rmFile(",
            "\"",
            file_info.path,
            "\",\"",
            file_info.name,
            file_info.extension,
            "\",",
            if (file_info.extension.len == 0) "true" else "false",
            ");"
        };
        break :blk try std.mem.concat(status.allocator, u8, &parts);
    };
    defer status.allocator.free(code);

    try status.current_function.addCode(code);
}



const Entity = parse_helper.Entity;

fn summon(context: []const u8) !void {
    var context_index: usize = 0;
    const entity_type = removeNamespaceOrReturn(getNextArgument(context, &context_index, ' ').?, "minecraft");

    // check coordinates to be ~ ~ ~
    for (1..3) |_| {
        if (!std.mem.eql(u8, getNextArgument(context, &context_index, ' ').?, "~")) return DatapackErrors.UnknownArgument;
    }
    context_index += 3;
    
    const nbt = getNextArgument(context, &context_index, '}').?;

    const entity = try Entity.init(status.allocator, entity_type, nbt);
    
    try status.spawnEntity(entity);

    switch (entity.nbt) {
        .TextDisplay => |d| {
            const code = blk: {
                if (d.text.len == 0) {
                    const parts = [5][]const u8{
                        "const ",
                        entity.uuid,
                        " = try std.fs.cwd().createFile(\"",
                        d.CustomName,
                        "\", .{ .read = true, .truncate = false });",
                    };
                    break :blk try std.mem.concat(status.allocator, u8, &parts);
                } 
                else {
                    const parts =[11][]const u8{
                        "const ",
                        entity.uuid,
                        " = try std.fs.cwd().createFile(\"",
                        d.CustomName,
                        "\", .{ .read = true, .truncate = false });\ntry ",
                        entity.uuid,
                        ".seekFromEnd(0);\ntry ",
                        entity.uuid,
                        ".writeAll(\"",
                        d.text,
                        "\");"
                    };
                    break :blk try std.mem.concat(status.allocator, u8, &parts);
                }
            };
            defer status.allocator.free(code);

            try status.current_function.addCode(code);
        },
    }
}



fn kill(context: []const u8) !void {
    var context_index: usize = 0;
    const selector = Selector.parse(getNextArgument(context, &context_index, ' ').?);
    
    if (!std.mem.eql(u8, selector.selector_type, "@e")) return DatapackErrors.UnknownSelectorType;

    const uuid = try parse_helper.sanatizeUuid(status.allocator, getDataValue(selector.arguments.?.nbt, "UUID:[I;", .array));
    defer status.allocator.free(uuid);

    var entity = status.entity_map.get(uuid) orelse return;
    _ = status.entity_map.remove(uuid);
    defer entity.deinit();

    const code = switch (entity.entity_type) {
        .TextDisplay => blk: {
            const parts = [2][]const u8{
                uuid,
                ".close();"
            };
            break :blk try std.mem.concat(status.allocator, u8, &parts);
        },
    };
    defer status.allocator.free(code);

    try status.current_function.addCode(code);
}



// fn data(context: []const u8) !void {
//     var context_index: usize = 0;
//     const modify_method = getNextArgument(context, &context_index, ' ').?;
//     const target_type = getNextArgument(context, &context_index, ' ').?;
//     const target = getNextArgument(context, &context_index, ' ').?;
//     const new_nbt = getDataValue(getNextArgument(context, &context_index, ' ').?, "text:\"", .string);

//     switch (parse_helper.DataModificationMethods.stringToEnum(modify_method)) {
//         .Merge => {
//             const dataTarget = Target.parse(target_type, target);
            
//             switch (dataTarget) {
//                 .Entity => |*d| d.overwriteData(new_nbt),
//                 .Storage => |*d| d.overwriteData(),
//                 .Block => |*d| d.overwriteData(),
//             }
//         },
//         else => return DatapackErrors.UnknownArgument
//     }

//     const uuid = try parse_helper.sanatizeUuid(status.allocator, getDataValue(Selector.parse(target).arguments.?.nbt, "UUID:[I;", .array));
//     defer status.allocator.free(uuid);

//     const code = blk: {
//         const parts = [5][]const u8{
//             "try ",
//             uuid,
//             ".writeAll(\"",
//             new_nbt,
//             "\");"
//         };
//         break :blk try std.mem.concat(status.allocator, u8, &parts);
//     };
//     defer status.allocator.free(code);

//     try status.current_function.addCode(code);
// }

