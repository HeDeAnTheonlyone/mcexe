
const std = @import("std");
const manager = @import("manager.zig");
const array = @import("util/array.zig");



pub var status: Status = undefined; 

const Status = struct {
    imports: std.ArrayList([]const u8),
    globals: std.ArrayList([]const u8),
    code: std.ArrayList(u8),
    var_count: usize = 0,

    fn init(allocator: std.mem.Allocator) !Status {
        const stat = Status {
            .imports = std.ArrayList([]const u8).init(allocator),
            .globals = std.ArrayList([]const u8).init(allocator),
            .code = std.ArrayList(u8).init(allocator),
        };

        return stat;
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.globals.deinit();
        self.code.deinit();
    }

    /// Returns a new variable name to use in the interpreted code. It starts with 1 and counts up for each new variable. The returned name is `_<count>`.
    fn createNextVariableName(self: *Status, allocator: std.mem.Allocator) ![]const u8 {
        self.var_count += 1;
        return try std.fmt.allocPrint(allocator, "_{d}", .{self.var_count});
    }

    /// Appends an import, if it doesn't already exists. Imports are written to the file first.
    fn addImport(self: *Status, import_code: []const u8) !void {
        if (array.contains([]const u8, self.imports.items, import_code) == null) {
            try self.imports.append(import_code);
        }
    }

    /// Appends a global variable declaration if it doesn't already exist. They get written in the file after the imports.
    fn addGlobal(self: *Status, global_var: []const u8) !void {
        if (array.contains([]const u8, self.globals.items, global_var) == null) {
            try self.globals.append(global_var);
        }
    }

    /// Appends a piece of code. Code gets written after the imports and globals.
    fn addCode(self: *Status, code: []const u8) !void {
        try self.code.appendSlice(code);
        try self.code.append('\n');
    }

    /// Generates the output files and writes the interpreted code to it.
    pub fn flushCode(self: *Status, pack_path: []const u8) !void {
        const file = try generateOutFiles(manager.global_allocator, pack_path);
        defer file.close();

        // imports
        _ = try file.write("const std = @import(\"std\");\n");
        _ = try file.write("const interpret = @import(\"interpretation.zig\");\n");
        for (self.imports.items) |import| {
            _ = try file.write(import);
            _ = try file.write("\n");
        }
        //

        _ = try file.write("\n\n\n");
        _ = try file.write("pub fn main() !void {\n");
    
        // globals
        _ = try file.write("var gpa = std.heap.GeneralPurposeAllocator(.{}){};\n");
        _ = try file.write("const allocator = gpa.allocator();\n");
        _ = try file.write("_ = allocator;\n");
        _ = try file.write("defer _ = gpa.deinit();\n");
        for (self.globals.items) |global| {
            _ = try file.write(global);
            _ = try file.write("\n");
        }
        //

        // other code
        _ = try file.write("\n");
        _ = try file.write(self.code.items);
        _ = try file.write("\nstd.time.sleep(5 * std.time.ns_per_s);\n");
        _ = try file.write("std.debug.print(\"\\nConsole closes in 5 seconds.\", .{});\n");
        _ = try file.write("std.time.sleep(5 * std.time.ns_per_s);\n}");
        //
    }
};

/// Generates the build.zig, copies the interpretation function file, and generateds the interpreted Zig file.
fn generateOutFiles(allocator: std.mem.Allocator, pack_path: []const u8) !std.fs.File {
    var pack_dir = try std.fs.openDirAbsolute(pack_path, .{});
    defer pack_dir.close();

    var out_dir = try std.fs.Dir.makeOpenPath(pack_dir, "out", .{});
    defer out_dir.close();

    // copy interpreter.zig
    const lib_source_path = blk: {
        const dir = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(dir);

        const parts = [2][]const u8{
            dir,
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
    const build_file = try pack_dir.createFile("out/build.zig", .{});
    defer build_file.close();

    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
    const namespace = path_iter.first();

    const build_code = blk: {
        const parts = [14][]const u8{
            "const std = @import(\"std\");\n\n",
            "pub fn build(b: *std.Build) void {\n",
            "const exe = b.addExecutable(.{\n",
            ".name = \"",
            namespace,
            "\",\n",
            ".root_source_file = b.path(\"",
            namespace,
            ".zig\"),\n",
            ".target = b.standardTargetOptions(.{}),\n",
            ".optimize = b.standardOptimizeOption(.{}),\n",
            "});\n\n",
            "b.installArtifact(exe);\n",
            "}"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(build_code);
    _ = try build_file.writeAll(build_code);

    // creat and return interpretation file
    const out_path = blk: {
        const parts = [3][]const u8{
            "out/",
            namespace,
            ".zig"
        };        
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(out_path);

    return try pack_dir.createFile(out_path, .{});
}

pub fn initInterpreterStatus(allocator: std.mem.Allocator) !void {
    status = try Status.init(allocator);
}

pub fn deinitInterpreterStatus() void {
    status.deinit();
}



const Commands = enum {
    none,
    say,
    give,
    clear,
};

pub fn evalCmd(command: []const u8) !void {
    const primary_cmd = getPrimaryCmd(command) orelse return;
    
    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .say => try say(command[primary_cmd.len + 1..]),
        .give => try give(command[primary_cmd.len + 1..]),
        .clear => try clear(command[primary_cmd.len + 1..]),
        else => {}
    }
}

fn getPrimaryCmd(command: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, command, "#"))
        return null;
    
    if (std.mem.startsWith(u8, command, " "))
        return null;
    
    if (std.mem.startsWith(u8, command, "\n"))
        return null;
    
    return getNextArgument(command, 0, ' ');
}

/// Returns the next argument in the command from the given starting index or null if there is no next argument. !!!DON'T USE `std.mem.splitScalar()` THIS FUNCTION IS NEEDED FOR LATER DEVELOPMENT!!!
fn getNextArgument(command: []const u8, start: usize, delimiter: u8) ?[]const u8 {
    if (start >= command.len) return null;
    const end = std.mem.indexOfScalarPos(u8, command, start, delimiter) orelse command.len;
    return command[start..end];
}



fn say(context: []const u8) !void {    
    try status.addGlobal("const stdout = std.io.getStdOut();");

    const code_parts = [3][]const u8{
        "_ = try stdout.write(\"",
        context,
        "\\n\");"
    };
    const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
    defer manager.global_allocator.free(code);
    try status.addCode(code);
}



// fn tellraw(msg: []const u8) !void {
// }



const FileInfo = struct {
    path: []const u8,
    name: []const u8,
    extension: []const u8,

    fn parse(context: []const u8) FileInfo {
        const selector = getNextArgument(context, 0, ' ').?;
        const item = getNextArgument(context, selector.len + 1, '[').?;
        const item_component = getNextArgument(context, selector.len + item.len + 2, ']').?;

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

        break :blk try std.mem.concat(manager.global_allocator, u8, &parts);
    };
    defer manager.global_allocator.free(code);
    try status.addCode(code);
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

        break :blk try std.mem.concat(manager.global_allocator, u8, &parts);
    };
    defer manager.global_allocator.free(code);
    try status.addCode(code);
}