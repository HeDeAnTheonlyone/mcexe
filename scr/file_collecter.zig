
const std = @import("std");
const Settings = @import("settings.zig").Settings;

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
    const full_path = try std.fmt.allocPrint(
        allocator, 
        "{s}/data/minecraft/tags/functions/{s}.json",
        .{settings.path, func_list.getStrName()}
    );
    defer allocator.free(full_path);

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const buffer = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(buffer);

    return try std.json.parseFromSlice(FunctionList, allocator, buffer, .{});
}



// TODO Correctly implement function struct
const Function = struct {
    allocator: std.mem.Allocator,
    commands: []const []const u8,
    index: usize = 0,

    /// Returns a an iteratior struct that holds an allocator and a list of commands
    pub fn init(self: *Function, allocator: std.mem.Allocator, settings: Settings, function_path: []u8) Function {
        self.allocator = allocator;
        const func_path = std.mem.splitScalar(u8, function_path, ':');
        const full_path = std.fmt.allocPrint(allocator, "{s}{s}{}", .{settings.path, func_path.first(), func_path.next()});
        _ = full_path;

        try std.fs.openDirAbsolute(settings.path, .{});
    }
};
