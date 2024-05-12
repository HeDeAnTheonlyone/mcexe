
const std = @import("std");



pub const Settings = struct {
    abs: bool,
    path: []u8,

    /// Initialses a Settings struct.
    /// `path`: Path to the datapack. Leave blank if executed in the datapacks root directory.
    /// `abs`: Is an absolute file path used?
    pub fn init() Settings {
        return Settings{
            .abs = false,
            .path = "",
        };
    }

    /// Applies the command line arguments to the settings 
    pub fn setSettings(self: *Settings, args_arr: [][:0]u8) void {
        for (args_arr, 0..) |arg, index| {
            if (std.mem.eql(u8, arg, "-abs")) {
                self.abs = true;
            }
            else if (std.mem.eql(u8, arg, "-path")) {
                self.path = args_arr[index + 1];
                std.mem.replaceScalar(u8, self.path, '\\', '/');
            }
        }
    }
};