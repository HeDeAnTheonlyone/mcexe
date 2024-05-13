
const std = @import("std");
const Settings = @import("settings.zig").Settings;
const fCollecter = @import("file_collecter.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};



// TODO After project testing, remove mcexe.exe from environment variables

pub fn main() !void {
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const arguments: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arguments);

    const settings = try Settings.init(arguments, allocator);
    defer settings.deinit();

    const load_functions = fCollecter.getFuncFilesList(allocator, settings, .load) catch |err| {
        if (err == std.json.Error.SyntaxError){
            std.debug.print("Syntax error in '{s}/data/minecraft/tags/functions/load.json'", .{settings.path});
        }
        else {
            std.debug.print("{any}", .{err});
        }
        return;
    };
    defer load_functions.deinit();

    for (load_functions.value.values) |func| {
        var function = try fCollecter.Function.init(allocator, settings, func);
        defer function.deinit();

        while (function.commands.next()) |cmd| {
            std.debug.print("{s}\n", .{cmd});
        }
    }
}