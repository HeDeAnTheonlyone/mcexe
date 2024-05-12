
const std = @import("std");
const Settings = @import("settings.zig").Settings;

const func_list_path = "/data/minecraft/tags/functions/";
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
    const full_load_path = try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}.json",
        .{settings.path, func_list_path, func_list.getStrName()}
    );
    defer allocator.free(full_load_path);

    const file = if (settings.abs) 
        try std.fs.cwd().openFile(full_load_path, .{})
    else
        try std.fs.openFileAbsolute(full_load_path, .{});
    defer file.close();

    const buffer = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(buffer);

    return try std.json.parseFromSlice(FunctionList, allocator, buffer, .{});
}



// TODO Correctly implement function struct
const Function = struct {
    const allocator: std.mem.Allocator = undefined;
};

pub fn getFunction(allocator: std.mem.Allocator, ) void {

}
