
const std = @import("std");


pub fn removeFile(director: std.fs.Dir, file_name: []const u8) !void {
    var iterator = director.iterate();

    while (try iterator.next()) |file| {
        const ext_index = std.mem.lastIndexOfScalar(u8, file.name, '.').?;
        
        if (std.mem.eql(u8, file_name, file.name[0..ext_index])) {
            try director.deleteFile(file.name);
        }
    }
}