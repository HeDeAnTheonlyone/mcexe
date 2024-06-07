
const std = @import("std");
const manager = @import("manager.zig");
const f_collector = @import("util/file_collector.zig");
const array = @import("util/array.zig");

const ArrayList = std.ArrayList;



pub var status: Status = undefined;

const Status = struct {
    allocator: std.mem.Allocator,
    imports: std.ArrayList([]const u8),
    function_stack: std.ArrayList([]const u8),
    function_map: std.StringHashMap(InterpretedFunction),
    current_function: *InterpretedFunction,
    var_count: usize = 0,

    fn init(allocator: std.mem.Allocator) !Status {
        return Status {
            .allocator = allocator,
            .imports = std.ArrayList([]const u8).init(allocator),
            .function_stack = std.ArrayList([]const u8).init(allocator),
            .function_map = std.StringHashMap(InterpretedFunction).init(allocator),
            .current_function = undefined
        };
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.function_stack.deinit();
        self.function_map.deinit();
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
        _ = try file.write("std.time.sleep(5 * std.time.ns_per_s);\n\n\n\n}");

        var function_iterator = self.function_map.valueIterator();
        while (function_iterator.next()) |func| {

            _ = try file.write("fn ");
            _ = try file.write(func.name);
            _ = try file.write("() !isize {\n");

            for (func.top_vars.items) |top_var| {
                _ = try file.write(top_var);
            }
            _ = try file.write("\n");
            _ = try file.write(func.code.items);
            _ = try file.write("return 0;\n}\n\n");

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

    while (func.commands.next()) |cmd| {
        try evalCmd(cmd);
    }
}



const Commands = enum {
    none,
    function,
    say,
    give,
    clear,
};

fn evalCmd(command: []const u8) !void {
    const primary_cmd = getPrimaryCmd(command) orelse return;
    const context_index = primary_cmd.len + 1;
    
    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .function => try function(command[context_index..]),
        .say => try say(command[context_index..]),
        .give => try give(command[context_index..]),
        .clear => try clear(command[context_index..]),
        else => {
            std.debug.print("\nSkipped unknown command'{s}'", .{command});
        }
    }
}

fn getPrimaryCmd(command: []const u8) ?[]const u8 {
    const first_char = std.mem.indexOfNone(u8, command, " ") orelse return null;

    if (std.mem.startsWith(u8, command[first_char..], "#"))
        return null;
    
    if (std.mem.startsWith(u8, command[first_char..], "\n"))
        return null;
    
    var i: usize = 0;
    return getNextArgument(command[first_char..], &i, ' ');
}

/// Returns the next argument in the command from the given starting index or null if there is no next argument. It also increases the given index value to the next arguments start index. !!!DON'T USE `std.mem.splitScalar()` THIS FUNCTION IS NEEDED FOR LATER DEVELOPMENT!!!
fn getNextArgument(command: []const u8, start_index: *usize, delimiter: u8) ?[]const u8 {
    const start: usize = start_index.*;

    if (start >= command.len) return null;
    const end = std.mem.indexOfScalarPos(u8, command, start, delimiter) orelse command.len;

    start_index.* = end + 1;
    return command[start..end];
}



const FunctionCommandFunctionErrors = error {
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

fn function(context: []const u8) FunctionCommandFunctionErrors!void {
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



const FileInfo = struct {
    path: []const u8,
    name: []const u8,
    extension: []const u8,

    fn parse(context: []const u8) FileInfo {
        var context_index: usize = 0;

        const selector = getNextArgument(context, &context_index, ' ').?;
        const item = getNextArgument(context, &context_index, '[').?;
        const item_component = getNextArgument(context, &context_index, ']').?;

        //TODO currently only supports selectors that are names and plain @s
        return FileInfo {
            .path = if (std.mem.startsWith(u8, selector, "@")) "" else selector,
            .extension = if (std.mem.startsWith(u8, item, "minecraft:")) itemToExtension(item[10..]) else itemToExtension(item),
            .name = blk: {
                const index = std.mem.indexOf(u8, item_component, "item_name=").? + 10;
                break :blk std.mem.trim(u8, item_component[index..], "\"");
            }
        };
    }
};

fn itemToExtension(item: []const u8) []const u8 {
    return if (std.mem.eql(u8, item, "*")) ""
        else if (std.mem.eql(u8, item, "paper")) ".txt"
        else ".txt";
}

fn give(context: []const u8) !void {
    const file_info = FileInfo.parse(context);

    const code = blk: {
        const parts = [7][]const u8{
            "try interpret.mkFile(",
            "\"",
            file_info.path,
            "\",\"",
            file_info.name,
            file_info.extension,
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
            if (std.mem.eql(u8, file_info.extension, "")) "true" else "false",
            ");"
        };
        break :blk try std.mem.concat(status.allocator, u8, &parts);
    };
    defer status.allocator.free(code);

    try status.current_function.addCode(code);
}