
const std = @import("std");
const array = @import("util/array.zig");

const ArrayList = std.ArrayList;
const json = std.json;



/// Enum of vanilla builtin function tags with special functionality 
const VanillaFunctionLists = enum {
    tick,
    load,
    
    fn getStrName(self: VanillaFunctionLists) []const u8 {
        return switch (self) {
            .load => "load",
            .tick => "tick"
        };
    }
};

const FunctionList = struct {
    values: [][]u8
};

pub fn getFuncFilesList(allocator: std.mem.Allocator, pack_path: []const u8, comptime func_list: VanillaFunctionLists) !std.json.Parsed(FunctionList) {
    const path_parts = [4][]const u8{
        pack_path,
        "/data/minecraft/tags/functions/",
        func_list.getStrName(),
        ".json"
    };
    const full_path = try std.mem.concat(allocator, u8, &path_parts);
    defer allocator.free(full_path);

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const buffer = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(buffer);

    return try std.json.parseFromSlice(FunctionList, allocator, buffer, .{});
}



pub const Function = struct {
    raw_commands: ArrayList(u8),
    commands: std.mem.SplitIterator(u8, .scalar),

    /// Returns a struct that holds an allocator and a iterable list of commands
    pub fn init(allocator: std.mem.Allocator, pack_path: []const u8 , function_path: []const u8) !Function {
        var func_path = std.mem.splitScalar(u8, function_path, ':');
        const path_parts = [6][]const u8{
            pack_path,
            "/data/",
            func_path.first(),
            "/functions/",
            func_path.next().?,
            ".mcfunction"
        };
        const full_path = try std.mem.concat(allocator, u8, &path_parts);
        defer allocator.free(full_path);

        const file = try std.fs.openFileAbsolute(full_path, .{});
        defer file.close();

        const contents = try file.reader().readAllAlloc(allocator, 65536);
        const sanatized_contents = try array.removeScalar(u8, allocator, contents, '\r');
        allocator.free(contents);
        const cmds = std.mem.splitScalar(u8, sanatized_contents.items, '\n');

        return Function{
            .raw_commands = sanatized_contents,
            .commands = cmds
        };
    }

    pub fn deinit(self: *const Function) void {
        self.raw_commands.deinit();
    }
};
