
const std = @import("std");
const Settings = @import("settings.zig").Settings;
const fCollecter = @import("file_collecter.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};



// TODO After project testing, remove mcexe.exe from environment variables

pub fn main() !void {
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const arguments = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arguments);

    var settings = Settings.init();
    settings.setSettings(arguments);

    const load_functions = fCollecter.getFuncFilesList(allocator, settings, .load) catch |err| {
        if (err == std.json.Error.SyntaxError)
            std.debug.print("Syntax error in '{s}/data/minecraft/tags/functions/load.json'", .{settings.path});
        return;
    };
    defer load_functions.deinit();

    for (load_functions.value.values) |func| {
        std.debug.print("{s}\n", .{func});
    }
    std.debug.print("\n{any}\n{s}\n\n", .{settings.abs, settings.path});
}