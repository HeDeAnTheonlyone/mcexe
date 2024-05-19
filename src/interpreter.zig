
const std = @import("std");
const manager = @import("manager.zig");
const array = @import("util/array.zig");



pub var status: Status = undefined; 

const Status = struct {
    imports: std.ArrayList([]const u8),
    globals: std.ArrayList([]const u8),
    code: std.ArrayList(u8),
    curr_cmd_next_arg_index: usize,

    fn init(allocator: std.mem.Allocator) !Status {
        var stat = Status {
            .imports = std.ArrayList([]const u8).init(allocator),
            .globals = std.ArrayList([]const u8).init(allocator),
            .code = std.ArrayList(u8).init(allocator),
            .curr_cmd_next_arg_index = 0,
        };

        try stat.addImport(@constCast("const std = @import(\"std\");"));
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
        _ = try file.write("std.debug.print(\"Console closes in 5 seconds.\", .{});\n");
        _ = try file.write("std.time.sleep(5 * std.time.ns_per_s);\n}");
    }
};

/// Generates the interpreted .zig file.
fn generateOutFiles(allocator: std.mem.Allocator, pack_path: []const u8) !std.fs.File {
    var pack_dir = try std.fs.openDirAbsolute(pack_path, .{});
    defer pack_dir.close();
    try std.fs.Dir.makePath(pack_dir, "out");

    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
    const out_path_parts = [4][]const u8{
        pack_path,
        "/out/",
        path_iter.first(),
        ".zig"
    };
    const out_file_path = try std.mem.concat(allocator, u8, &out_path_parts);
    defer allocator.free(out_file_path);

    return try std.fs.createFileAbsolute(out_file_path, .{});
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
};

pub fn evalCmd(command: []const u8) !void {
    status.curr_cmd_next_arg_index = 0;
    const primary_cmd = getPrimaryCmd(command) orelse return;
    
    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .say => try say(command[primary_cmd.len + 1..]),
        // .give => try give(command[primary_cmd.len + 1..]),
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
    
    return getNextArgument(command, 0);
}

fn getNextArgument(command: []const u8, start: usize) ?[]const u8 {
    var end = start;
    while (command[end] != ' ') : (end += 1) {}

    status.curr_cmd_next_arg_index = end + 1;
    return command[start..end];
}



fn say(context: []const u8) !void {    
    try status.addGlobal(@constCast("const stdout = std.io.getStdOut();"));

    const code_parts = [3][]const u8{"_ = try stdout.write(\"", context, "\");"};
    const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
    defer manager.global_allocator.free(code);
    try status.addCode(code);
}

// fn tellraw(msg: []const u8) !void {
//     std.json.Parsed(comptime T: type)

//     std.json.parseFromSlice(comptime T: type, allocator: Allocator, s: []const u8, options: ParseOptions)

    
// }

fn give(context: []const u8) !void {
    
}

// fn clear(context: ?[]const u8) !void {

// }