
const std = @import("std");
const manager = @import("manager.zig");
const array = @import("util/array.zig");



pub var status: Status = undefined; 

const Status = struct {
    imports: std.ArrayList([]const u8),
    code: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) !Status {
        var stat = Status {
            .imports = std.ArrayList([]const u8).init(allocator),
            .code = std.ArrayList(u8).init(allocator)
        };

        try stat.addImportCode(@constCast("const std = @import(\"std\");"));
        try stat.addCode("pub fn main() void {\n");

        return stat;
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.code.deinit();
    }

    /// Appends an import, if it doesn't already exists. 
    fn addImportCode(self: *Status, import_code: []const u8) !void {
        if (array.contains([]const u8, self.imports.items, import_code) == null) {
            try self.imports.append(import_code);
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

        for (self.*.imports.items) |import| {
            _ = try file.write(import);
            _ = try file.write("\n");
        }
        _ = try file.write("\n\n\n");
        _ = try file.write(self.*.code.items);
        _ = try file.write("while (true) {}\n}");
    }
};

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
};

pub fn evalCmd(command: []const u8) !void {
    std.debug.print("\n_i_\n{s}\n_i_\n", .{command}); //TEMP
    const primary_cmd = getPrimaryCmd(command) orelse return;
    
    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .say => try say(command[primary_cmd.len + 1..]),
        else => std.debug.print("\n_E_\n{s}\n_E_\n", .{primary_cmd}) //TEMP}
    }
}

fn getPrimaryCmd(command: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, command, "#"))
        return null;
    
    if (std.mem.startsWith(u8, command, " "))
        return null;
    
    if (std.mem.startsWith(u8, command, "\n"))
        return null;
    
    return if (std.mem.indexOfScalar(u8, command, ' ')) |index| command[0..index] else null;
}



fn say(msg: []const u8) !void {
    std.debug.print("\n_s_\n{s}\n_s_\n", .{msg}); //TEMP
    try status.addImportCode(@constCast("const stdout = std.io.getStdOut();"));

    const code_parts = [3][]const u8{"stdout.write(\"", msg, "\");"};
    const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
    defer manager.global_allocator.free(code);
    try status.addCode(code);
}  