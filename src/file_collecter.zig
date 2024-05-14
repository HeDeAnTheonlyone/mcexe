
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



pub const Function = struct {
    allocator: std.mem.Allocator,
    commands: std.mem.SplitIterator(u8, .scalar),

    /// Returns a struct that holds an allocator and a iterable list of commands
    pub fn init(allocator: std.mem.Allocator, settings: Settings, function_path: []u8) !Function {// Function {
        var func_path = std.mem.splitScalar(u8, function_path, ':');
        const full_path = try std.fmt.allocPrint(allocator, "{s}/data/{s}/functions/{s}.mcfunction", .{settings.path, func_path.first(), func_path.next().?});
        defer allocator.free(full_path);

        std.debug.print("\n\n{s}\n\n", .{full_path});

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