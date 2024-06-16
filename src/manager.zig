
const std = @import("std");
const array = @import("util/array.zig");



var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
pub var global_allocator: std.mem.Allocator = undefined;

pub fn initGlobalAllocactor() void {
    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    global_allocator = gpa.allocator();
}

pub fn deinitGlobalAllocator() void {
    _ = gpa.deinit();
}



pub var settings: Settings = undefined;

/// `allocator`: Holds the allocator for the structs fields.
/// `path`: Path to the datapack. Leave blank if executed in the datapacks root directory.
pub const Settings = struct {
    allocator: std.mem.Allocator,
    exe_dir_path: []const u8,
    path: []const u8,

    fn init(args_arr: [][]const u8, allocator: std.mem.Allocator) !Settings {        
        return  Settings{
            .allocator = allocator,
            .exe_dir_path = exe_path_blk: {
                const path = try std.fs.selfExeDirPathAlloc(allocator);
                std.mem.replaceScalar(u8, path, '\\', '/');
                break :exe_path_blk path;
            },
            .path = path_blk: {
                const tmp_path = if (array.contains([]const u8, args_arr, "--path")) |index| args_arr[index + 1] else "";
                const tmp_full_path = try std.fs.cwd().realpathAlloc(allocator, tmp_path);
                std.mem.replaceScalar(u8, tmp_full_path, '\\', '/');
                break :path_blk tmp_full_path;
            }
        };
    }

    fn deinit(self: *Settings) void {
        self.allocator.free(self.exe_dir_path);
        self.allocator.free(self.path);
    }
};

pub fn initSettings(args_arr: [][]u8, allocator: std.mem.Allocator) !void {
    settings = try Settings.init(args_arr, allocator);
}

pub fn deinitSettings() void {
    settings.deinit();
}



pub const help_msg = 
    \\
    \\Usage: mcexe [options]
    \\
    \\Options:
    \\  
    \\  -h, --help                  Print command and options usage
    \\  --path [path]               Set absolute or relative path to the target datapack
    \\                              (if option is not present or left blank it uses the current working directory)
    \\ 
;