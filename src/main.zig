
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
    //try compileInterpretation(allocator, build,  settings.path);
}



fn initAll() !void {
    manager.initGlobalAllocactor(); // Allocator hast to be initialized before everything else!
    try interpreter.initInterpreterStatus(manager.global_allocator);
}

fn deinitAll() void {
    interpreter.deinitInterpreterStatus();
    manager.deinitGlobalAllocator(); // Allocator hast to be freed after everything else was freed!
}


// TODO maybe delete
fn compileInterpretation(allocator: std.mem.Allocator, b: *std.Build, pack_path: []const u8) !void {
    var path_iter = std.mem.splitBackwardsScalar(u8, pack_path, '/');
    const namespace = path_iter.first();
    
    const path_parts = [_][]const u8{
        pack_path,
        "/out/",
        namespace,
        ".zig"
    };
    const source_path = try std.mem.concat(allocator, u8, &path_parts);
    defer allocator.free(source_path);

    const exe = b.addExecutable(.{
        .name = namespace,
        .root_source_file = .{ .path = source_path },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{ .safe })
    });

    b.installArtifact(exe);
}