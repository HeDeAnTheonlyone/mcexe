const std = @import("std");



pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "interpret",
    //     .root_source_file = b.path("interpret_lib/root.zig"),
    //     .target = target,
    //     .optimize = optimize
    // });

    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "mcexe",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });

    b.installArtifact(exe);
}