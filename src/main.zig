
const std = @import("std");
const manager = @import("manager.zig");
const fCollecter = @import("file_collecter.zig");
const interpreter = @import("interpreter.zig");



// TODO After project testing, remove mcexe.exe from environment variables

pub fn main() !void {
    initAll();
    defer deinitAll();

    const allocator = manager.global_allocator;

    const arguments: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arguments);

    try manager.initSettings(arguments, allocator);
    defer manager.deinitSettings();
    const settings = manager.settings;

    const load_functions = fCollecter.getFuncFilesList(allocator, settings.path, .load) catch |err| {
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
        var function = try fCollecter.Function.init(allocator, settings.path, func);
        defer function.deinit();

        try interpreter.evalCmd(function.commands.first());
        while (function.commands.next()) |cmd| {
            try interpreter.evalCmd(cmd);
        }
    }

    // TODO use this file to print out the code
    try generateOutFiles(allocator, settings.path);
}



fn initAll() void {
    manager.initGlobalAllocactor(); // Allocator hast to be initialized before everything else!
    interpreter.initInterpreterStatus(manager.global_allocator);
}

fn deinitAll() void {
    interpreter.deinitInterpreterStatus();
    manager.deinitGlobalAllocator(); // Allocator hast to be freed after everything else was freed!
}



fn generateOutFiles(allocator: std.mem.Allocator, pack_path: []const u8) !void {
    var pack_dir = try std.fs.openDirAbsolute(pack_path, .{});
    defer pack_dir.close();
    try std.fs.Dir.makePath(pack_dir, "out");

    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
    const out_path_parts = [4][]const u8{
        pack_path,
        "/out/",
        path_iter.first(),
        ".zig"
    };
    const out_file_path = try std.mem.concat(allocator, u8, &out_path_parts);
    defer allocator.free(out_file_path);

    const out_file = try std.fs.createFileAbsolute(out_file_path, .{ .read = true });
    defer out_file.close();
}
