
const std = @import("std");
const Settings = @import("manager.zig").Settings;

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

pub fn getFuncFilesList(allocator: std.mem.Allocator, settings: Settings, comptime func_list: VanillaFunctionLists) !std.json.Parsed(FunctionList) {
    const path_parts = [4][]const u8{
        settings.path,
        "/data/minecraft/tags/functions/",
        func_list.getStrName(),
        ".json"
    };
    const full_path = try std.mem.concat(allocator, u8, &path_parts);
    defer allocator.free(full_path);

    std.debug.print("{s}\n", .{full_path}); //TEMP

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const buffer = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(buffer);

    return try std.json.parseFromSlice(FunctionList, allocator, buffer, .{});
}



pub const Function = struct {
    allocator: std.mem.Allocator,
    commands: std.mem.SplitIterator(u8, .scalar),

    /// Returns a struct that holds an allocator and a iterable list of commands
    pub fn init(allocator: std.mem.Allocator, settings: Settings, function_path: []u8) !Function {
        var func_path = std.mem.splitScalar(u8, function_path, ':');
        const path_parts = [6][]const u8{
            settings.path,
            "/data/",
            func_path.first(),
            "/functions/",
            func_path.next().?,
            ".mcfunction"
        };
        const full_path = try std.mem.concat(allocator, u8, &path_parts);
        defer allocator.free(full_path);

        std.debug.print("\n\n{s}\n\n", .{full_path}); //TEMP

        const file = try std.fs.openFileAbsolute(full_path, .{});
        defer file.close();

        const contents = try file.reader().readAllAlloc(allocator, 65536);
        const cmds = std.mem.splitScalar(u8, contents, '\n');

        return Function{
            .allocator = allocator,
            .commands = cmds
        };
    }

    pub fn deinit(self: *const Function) void {
        self.allocator.free(self.*.commands.buffer);
    }
};
