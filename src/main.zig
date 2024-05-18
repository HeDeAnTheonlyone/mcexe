
const std = @import("std");
const manager = @import("manager.zig");
const fCollecter = @import("file_collecter.zig");
const interpreter = @import("interpreter.zig");



// TODO After project testing, remove mcexe.exe from environment variables

pub fn main() !void {
    try initAll();
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

    try interpreter.status.flushCode(settings.path);

    // TODO add dynamic compilation of the generated Zig code.
    try compileInterpretation(allocator, settings.path);
}



fn initAll() !void {
    manager.initGlobalAllocactor(); // Allocator hast to be initialized before everything else!
    try interpreter.initInterpreterStatus(manager.global_allocator);
}

fn deinitAll() void {
    interpreter.deinitInterpreterStatus();
    manager.deinitGlobalAllocator(); // Allocator hast to be freed after everything else was freed!
}



fn compileInterpretation(allocator: std.mem.Allocator, pack_path: []const u8) !void {
    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
    const namespace = path_iter.first();
    
    const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
    const exe_path_parts = [2][]const u8{
        exe_dir_path,
        "/zig.exe"
    };
    const exe_path = try std.mem.concat(allocator, u8, &exe_path_parts);
    defer allocator.free(exe_path);
    allocator.free(exe_dir_path);
    std.mem.replaceScalar(u8, exe_path, '\\', '/');

    const source_path_parts = [4][]const u8{
        pack_path,
        "/out/",
        namespace,
        ".zig"
    };
    const source_path = try std.mem.concat(allocator, u8, &source_path_parts);
    defer allocator.free(source_path);

    const out_path_parts = [_][]const u8{
        "-femit-bin=",
        pack_path,
        "/out/",
        namespace,
        ".exe"
    };
    const out_path = try std.mem.concat(allocator, u8, &out_path_parts);
    defer allocator.free(out_path);

    // std.debug.print("\n{s}\n{s}\n{s}\n\n", .{
    //     exe_path,
    //     source_path,
    //     out_path
    // }); //TEMP

    const comp_args = [4][]const u8{
        exe_path,
        "build-exe",
        source_path,
        out_path
    };

    var compile = std.process.Child.init(&comp_args, allocator);
    const result = try std.process.Child.spawnAndWait(&compile);

    std.debug.print("{any}", .{result});
}