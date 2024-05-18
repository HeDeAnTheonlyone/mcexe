
const std = @import("std");

const ArrayList = std.ArrayList;



/// Searches a given array for a given value and returns the index of the first element that matches or null if no element matches.
pub fn contains(comptime T: type, haystack: []T, needle: T) ?usize {
    return for (haystack, 0..) |element, index| {
        if (std.mem.eql(@TypeOf(element[0]), element, needle)) break index;
    }
    else null;
}

/// Returns a newly allocated array without the scalar value
pub fn removeScalar(comptime T: type, allocator: std.mem.Allocator, buffer: []T, scalar: T) ![]u8 {
    var array_parts = ArrayList([]const u8).init(allocator);
    defer array_parts.deinit();
    
    var last_index: usize = 0;
    for (buffer, 0..) |element, index| {
        if (element == scalar){
            try array_parts.append(buffer[last_index..index]);
            last_index = index + 1;
        }
    }
    
    return try std.mem.concat(allocator, T, array_parts.items);
}
