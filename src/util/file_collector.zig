
const std = @import("std");
const array = @import("array.zig");

const ArrayList = std.ArrayList;
const json = std.json;



const FunctionFileList = struct {
    values: [][]u8
};

pub fn getFuncFilesList(allocator: std.mem.Allocator, pack_path: []const u8, comptime func_list: enum {load, tick}) !std.json.Parsed(FunctionFileList) {
    const full_path = blk: {
        const parts = [4][]const u8{
            pack_path,
            "/data/minecraft/tags/function/",
            if (func_list == .load) "load" else "tick",
            ".json"
        };

        break :blk try std.mem.concat(allocator, u8, &parts);
    };
    defer allocator.free(full_path);

    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    const buffer = try file.reader().readAllAlloc(allocator, 1024);
    defer allocator.free(buffer);

    return try std.json.parseFromSlice(FunctionFileList, allocator, buffer, .{});
}


/// The contents of the read function
pub const Function = struct {
    name: []const u8,
    raw_commands: ArrayList(u8),
    commands: std.mem.SplitIterator(u8, .scalar),

    /// Returns a struct that holds a mcfunction.
    pub fn init(allocator: std.mem.Allocator, pack_path: []const u8 , mc_function_path: []const u8) !Function {
        const full_path = blk: {
            const sperator_index = std.mem.indexOfScalar(u8, mc_function_path, ':').?;
            const parts = [6][]const u8{
                pack_path,
                "/data/",
                mc_function_path[0..sperator_index],
                "/function/",
                mc_function_path[sperator_index + 1..],
                ".mcfunction"
            };
            break :blk try std.mem.concat(allocator, u8, &parts);
        };
        defer allocator.free(full_path);

        const file = try std.fs.openFileAbsolute(full_path, .{});
        defer file.close();

        const contents = try file.reader().readAllAlloc(allocator, 1024 * 64);
        var sanatized_contents = try array.removeScalar(u8, allocator, contents, '\r');
        allocator.free(contents);
        try sanatized_contents.insert(0, '\n'); // This line is to not having to use ArrayList.first(). ArrayList.next() can be used directly.

        return Function{
            .name = blk: {
                const name = try allocator.alloc(u8, mc_function_path.len);
                @memcpy(name, mc_function_path);
                std.mem.replaceScalar(u8, name, ':', '_');
                std.mem.replaceScalar(u8, name, '/', '_');
                break :blk name;
            },
            .raw_commands = sanatized_contents,
            .commands = std.mem.splitScalar(u8, sanatized_contents.items, '\n')
        };
    }

    pub fn deinit(self: *Function) void {
        // name is later given to `interpreter.InterpretedFunction`, so it will be freed there.
        self.raw_commands.deinit();
    }
};
