
const std = @import("std");

const ArrayList = std.ArrayList;



/// Searches a given array for a given value and returns the index of the first element that matches or null if no element matches.
pub fn contains(comptime T: type, haystack: []T, needle: T) ?usize {
    return for (haystack, 0..) |element, index| {
        if (std.mem.eql(@TypeOf(element[0]), element, needle)) break index;
    }
    else null;
}

/// Returns a newly allocated ArrayList without the scalar value
pub fn removeScalar(comptime T: type, allocator: std.mem.Allocator, buffer: []T, scalar: T) !ArrayList(u8) {
    var clean_buffer = ArrayList(u8).init(allocator);
    
    var last_index: usize = 0;
    for (buffer, 0..) |element, index| {
        if (index + 1 == buffer.len) {
            try clean_buffer.appendSlice(buffer[last_index..index + 1]);
            break;
        }
        else if (element == scalar){
            try clean_buffer.appendSlice(buffer[last_index..index]);
            last_index = index + 1;
    }
    }
    return clean_buffer;
}
