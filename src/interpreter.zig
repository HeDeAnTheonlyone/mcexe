
const std = @import("std");
const manager = @import("manager.zig");
const array = @import("util/array.zig");



pub var status: Status = undefined; 

const Status = struct {
    imports: std.ArrayList([]const u8),
    globals: std.ArrayList([]const u8),
    code: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) !Status {
        var stat = Status {
            .imports = std.ArrayList([]const u8).init(allocator),
            .globals = std.ArrayList([]const u8).init(allocator),
            .code = std.ArrayList(u8).init(allocator),
        };

        try stat.addImport(@constCast("const std = @import(\"std\");"));
        // try stat

        try stat.addGlobal(@constCast("var gpa = std.heap.GeneralPurposeAllocator(.{}){};"));
        try stat.addGlobal(@constCast("const allocator = gpa.allocator();"));
        try stat.addGlobal(@constCast("defer _ = gpa.deinit();"));
        return stat;
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.globals.deinit();
        self.code.deinit();
    }

    /// Appends an import, if it doesn't already exists. 
    fn addImport(self: *Status, import_code: []const u8) !void {
        if (array.contains([]const u8, self.imports.items, import_code) == null) {
            try self.imports.append(import_code);
        }
    }

    fn addGlobal(self: *Status, global_var: []const u8) !void {
        if (array.contains([]const u8, self.globals.items, global_var) == null) {
            try self.globals.append(global_var);
        }
    }

    /// Appends a piece of code.
    fn addCode(self: *Status, code: []const u8) !void {
        try self.code.appendSlice(code);
        try self.code.append('\n');
    }

    pub fn flushCode(self: *Status, pack_path: []const u8) !void {
        const file = try generateOutFiles(manager.global_allocator, pack_path);
        defer file.close();

        for (self.imports.items) |import| {
            _ = try file.write(import);
            _ = try file.write("\n");
        }
    
        _ = try file.write("\n\n\n");
        _ = try file.write("pub fn main() !void {\n");
    
        for (self.globals.items) |global| {
            _ = try file.write(global);
            _ = try file.write("\n");
        }
        
        _ = try file.write("\n");
        _ = try file.write(self.code.items);
        _ = try file.write("\nstd.time.sleep(5 * std.time.ns_per_s);\n");
        _ = try file.write("std.debug.print(\"\\nConsole closes in 5 seconds.\", .{});\n");
        _ = try file.write("std.time.sleep(5 * std.time.ns_per_s);\n}");
    }
};

/// Generates the build.zig and interpreted .zig file.
fn generateOutFiles(allocator: std.mem.Allocator, pack_path: []const u8) !std.fs.File {
    var pack_dir = try std.fs.openDirAbsolute(pack_path, .{});
    defer pack_dir.close();
    try std.fs.Dir.makePath(pack_dir, "out");

    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');

    const build_file = try pack_dir.createFile("build.zig", .{});
    defer build_file.close();

    const build_code_parts = [14][]const u8{
        "const std = @import(\"std\");\n",
        "pub fn build(b: *std.Build) void {",
            "const exe = b.addExecutable(.{",
                ".name = \"",
                path_iter.first(),
                "\",",
                ".root_source_file = b.path(\"out/",
                path_iter.first(),
                "\"),",
                ".target = b.standardTargetOptions(.{}),",
                ".optimize = b.standardOptimizeOption(.{}),",
            "});\n",
            "b.installArtifact(exe);",
        "}"
    };
    const build_code = try std.mem.concat(allocator, u8, &build_code_parts);
    _ = try build_file.writeAll(build_code);

    const out_path_parts = [2][]const u8{
        path_iter.first(),
        ".zig"
    };
    const out_path = try std.mem.concat(allocator, u8, &out_path_parts);
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
        .clear => try give(command[primary_cmd.len + 1..]),
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
    try status.addGlobal(@constCast("const stdout = std.io.getStdOut();"));

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
    path: ?[]const u8,
    name: []const u8,
    extension: []const u8,

    fn get(context: []const u8) FileInfo {
        const selector = getNextArgument(context, 0, ' ').?;
        const item = getNextArgument(context, selector.len + 1, '[').?;
        const item_component = getNextArgument(context, selector.len + item.len + 2, ']').?;

        //TODO currently only supports selectors that are names and plain @s
        return FileInfo {
            .path = blk: {
                if (std.mem.startsWith(u8, selector, "@")) {
                    break :blk null;
                }
                else {
                    break :blk selector;
                }
            },
            .extension = if (std.mem.startsWith(u8, item, "minecraft:")) itemToExtension(item[10..]) else itemToExtension(item),
            .name = blk: {
                const index = std.mem.indexOf(u8, item_component, "item_name=").? + 10;
                const f_name = item_component[index..];
                break :blk std.mem.trim(u8, f_name, "\"");
            }
        };
    }
};

fn itemToExtension(item: []const u8) []const u8 {
    return if (std.mem.eql(u8, item, "*")) "_"
        else if (std.mem.eql(u8, item, "paper")) ".txt"
        else ".txt";
}

fn give(context: []const u8) !void {
    const file_info = FileInfo.get(context);

    if (file_info.path != null) {
        const code_parts = [7][]const u8{
            "const file = try std.fs.createFileAbsolute(\"",
            file_info.path.?,
            "/",
            file_info.name,
            file_info.extension,
            "\", .{});\n",
            "file.close();"
        };
        const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
        std.mem.replaceScalar(u8, code, '\\', '/');
        defer manager.global_allocator.free(code);
        try status.addCode(code);
    }
    else {
        const code_parts = [13][]const u8{
            "const var_file_path = try std.fs.cwd().realpathAlloc(allocator, \"\");\n",
            "std.mem.replaceScalar(u8, var_file_path, '\\\\', '/');\n",
            "defer allocator.free(var_file_path);\n",
            "const var_parts = [_][]const u8{",
            "var_file_path,",
            "\"/\",\"",
            file_info.name,
            file_info.extension
            ,"\"};\n",
            "const path = try std.mem.concat(allocator, u8, &var_parts);\n",
            "defer allocator.free(path);\n",
            "const file = try std.fs.createFileAbsolute(path, .{});\n",
            "file.close();"
        };
        const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
        defer manager.global_allocator.free(code);
        try status.addCode(code);
    }
}

//TODO
// fn clear(context: ?[]const u8) !void {

// }
