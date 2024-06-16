
const std = @import("std");
const manager = @import("manager.zig");
const f_collector = @import("util/file_collector.zig");
const array = @import("util/array.zig");
const interpreter = @import("interpreter.zig");



pub fn main() !void {
    try initAll();
    defer deinitAll();

    const allocator = manager.global_allocator;

    //TODO add option to specify the compile mode (safe, release, fast, small)
    const args_arr = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_arr);

    if (array.containsAny([]const u8, args_arr, &[2][]const u8{"-h", "--help"})) |index| {
        _ = index; // I will need this later
        const stdout = std.io.getStdOut();

        _ = try stdout.write(manager.help_msg);
        return;
    }

    try manager.initSettings(args_arr, allocator);
    defer manager.deinitSettings();
    const settings = manager.settings;

    const load_functions = try f_collector.getFuncFilesList(allocator, settings.path, .load);
    defer load_functions.deinit();

    var load_function_names = std.ArrayList([]const u8).init(allocator);
    defer load_function_names.deinit();

    for (load_functions.value.values) |func_path| {
        var function = try f_collector.Function.init(allocator, settings.path, func_path);
        defer function.deinit();

        try load_function_names.append(function.name);

        try interpreter.evalFunction(&function);
    }

    try interpreter.status.flushCode(settings.path, load_function_names);

    try compileInterpetedCode(allocator, settings.path);
}



fn initAll() !void {
    manager.initGlobalAllocactor(); // Allocator hast to be initialized before everything else!
    try interpreter.initInterpreterStatus(manager.global_allocator);
}

fn deinitAll() void {
    interpreter.deinitInterpreterStatus();
    manager.deinitGlobalAllocator(); // Allocator hast to be freed after everything else was freed!
}



fn compileInterpetedCode(allocator: std.mem.Allocator, pack_path: []const u8) !void {
    const exe_path = blk: {
        const parts = [2][]const u8{
            manager.settings.exe_dir_path,
            "/zig/zig.exe"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(exe_path);
    
    const build_file_path = blk: {
        const parts = [2][]const u8{
            pack_path,
            "/out/mcexe-out/build.zig"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(build_file_path);
    
    const cache_path = blk: {
        const parts = [2][]const u8{
            pack_path,
            "/out/zig-cache"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(cache_path);

    const out_dir = blk: {
        const parts = [2][]const u8{
            pack_path,
            "/out"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(out_dir);

    const comp_args = [8][]const u8{
        exe_path,
        "build",

        "--build-file",
        build_file_path,

        "--cache-dir",
        cache_path,

        "--prefix-exe-dir",
        out_dir
    };

    var compile = std.process.Child.init(&comp_args, allocator);
    _ = try std.process.Child.spawnAndWait(&compile);
}