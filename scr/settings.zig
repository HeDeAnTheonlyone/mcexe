
const std = @import("std");



pub const Settings = struct {
    allocator: std.mem.Allocator,
    path: []u8,

    /// Initialises a Settings struct.
    /// `allocator`: Holds the allocator for the structs fields.
    /// `path`: Path to the datapack. Leave blank if executed in the datapacks root directory.
    pub fn init(args_arr: [][:0]u8, allocator: std.mem.Allocator) !Settings {        
        return Settings{
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
                std.mem.replaceScalar(u8, tmp_full_path, '\\', '/');
                break :path_blk tmp_full_path;
            }
        };
    }


    pub fn deinit(self: *const Settings) void {
        self.allocator.free(self.*.path);
    }
};