
const std = @import("std");
const manager = @import("manager.zig");
const f_collector = @import("util/file_collector.zig");
const interpreter = @import("interpreter.zig");



pub fn main() !void {
    try initAll();
    defer deinitAll();

    const allocator = manager.global_allocator;

    const arguments: [][:0]u8 = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, arguments);

    // TODO add '-help' argument handling

    try manager.initSettings(arguments, allocator);
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
    const exe_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
    const exe_path = blk: {
        const parts = [2][]const u8{
            exe_dir_path,
            "/zig.exe"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(exe_path);
    allocator.free(exe_dir_path);
    std.mem.replaceScalar(u8, exe_path, '\\', '/');
    
    const build_file_path = blk: {
        const parts = [2][]const u8{
            pack_path,
            "/out/build.zig"
        };
        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(build_file_path);

    const comp_args = [4][]const u8{
        exe_path,
        "build",
        "--build-file",
        build_file_path
    };

    var compile = std.process.Child.init(&comp_args, allocator);
    _ = try std.process.Child.spawnAndWait(&compile);

    // std.debug.print("{any}", .{result}); //TEMP
}