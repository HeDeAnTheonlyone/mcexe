
const std = @import("std");



/// Create a file or folder at the given path. If the path doesn't exist, it will create all the needed folders. It recognizes absolute and relative paths.
pub fn mkFile(directory_path: []const u8, file_name: []const u8) !void {
    var dir = try std.fs.Dir.makeOpenPath(std.fs.cwd(), directory_path, .{});
    defer dir.close();

    var file = try dir.createFile(file_name, .{});
    defer file.close();
}



/// Deletes a file or directory and all it's contents at the given path. It recognizes absolute and relative paths.
pub fn rmFile(directory_path: []const u8, file_name: []const u8, ignore_extension: bool) !void {
    var directory = try std.fs.cwd().openDir(directory_path, .{.iterate = true});
    defer directory.close();

    var iterator = directory.iterate();

    if (ignore_extension) {
        while (try iterator.next()) |file| {
            const ext_index = std.mem.lastIndexOfScalar(u8, file.name, '.');

            if (ext_index == null) {
                if (std.mem.eql(u8, file_name, file.name)) {
                    try directory.deleteTree(file.name);
                }
            }
            else {
                if (std.mem.eql(u8, file_name, file.name[0..ext_index.?])) {
                    try directory.deleteTree(file.name);
                }
            }
        }
    }
    else try directory.deleteFile(file_name);
}