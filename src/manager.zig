
const std = @import("std");



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

pub const Settings = struct {
    allocator: std.mem.Allocator,
    path: []const u8,

    /// Initialises a Settings struct.
    /// `allocator`: Holds the allocator for the structs fields.
    /// `path`: Path to the datapack. Leave blank if executed in the datapacks root directory.
    fn init(args_arr: [][:0]u8, allocator: std.mem.Allocator) !Settings {        
        return  Settings{
            .allocator = allocator,
            .path = path_blk: {
                const tmp_path = for (args_arr, 0..) |arg, index| {
                    if (std.mem.eql(u8, arg, "-path")) {
                        if (index + 1 >= args_arr.len) {
                            break "";
                        }
                        else {
                            break args_arr[index + 1];
                        }
                    }
                }
                else "";
                const tmp_full_path = try std.fs.cwd().realpathAlloc(allocator, tmp_path);
                std.debug.print("\nI want to know this: {s}\n", .{tmp_full_path});
                std.mem.replaceScalar(u8, tmp_full_path, '\\', '/');
                break :path_blk tmp_full_path;
            }
        };
    }


    fn deinit(self: *Settings) void {
        self.allocator.free(self.*.path);
    }
};

pub fn initSettings(args_arr: [][:0]u8, allocator: std.mem.Allocator) !void {
    settings = try Settings.init(args_arr, allocator);
}

pub fn deinitSettings() void {
    settings.deinit();
}