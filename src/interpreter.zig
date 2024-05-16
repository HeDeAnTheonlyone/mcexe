
const std = @import("std");
const manager = @import("manager.zig");
const array = @import("util/array.zig");



var status: Status = undefined; 

const Status = struct {
    imports: std.ArrayList([]const u8),
    code: std.ArrayList(u8),

    fn init(allocator: std.mem.Allocator) Status {
        return Status {
            .imports = std.ArrayList([]const u8).init(allocator),
            .code = std.ArrayList(u8).init(allocator)
        };
    }

    fn deinit(self: *Status) void {
        self.imports.deinit();
        self.code.deinit();
    }

    fn addImportCode(self: *Status, import_code: []const u8) !void {
        if (array.contains([]const u8, self.imports.items, import_code) == null) {
            try self.imports.append(import_code);
        }
    }

    fn addCode(self: *Status, code: []const u8) !void {
        try self.code.appendSlice(code);
        try self.code.append('\n');
    }
};

pub fn initInterpreterStatus(allocator: std.mem.Allocator) void {
    status = Status.init(allocator);
}

pub fn deinitInterpreterStatus() void {
    status.deinit();
}



pub fn evalCmd(command: []const u8) !void {
    const primary_cmd = getPrimaryCmd(command) orelse return;
    
    switch (std.meta.stringToEnum(Commands, primary_cmd) orelse Commands.none) {
        .say => try say(command[primary_cmd.len + 1..]),
        else => {}
    }
}

fn getPrimaryCmd(command: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, command, "#"))
        return null;

    // TODO check for empty lines
    
    return if (std.mem.indexOfScalar(u8, command, ' ')) |index| command[0..index - 1] else null;
}



const Commands = enum {
    none,
    say,
    tellraw,
    give,
};

fn say(msg: []const u8) !void {
    try status.addImportCode(@constCast("const std = @import(\"std\");"));

    const code_parts = [3][]const u8{"stdout.write(\"", msg, "\");"};
    const code = try std.mem.concat(manager.global_allocator, u8, &code_parts);
    defer manager.global_allocator.free(code);
    try status.addCode(code);
}  