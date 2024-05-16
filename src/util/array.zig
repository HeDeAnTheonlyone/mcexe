
const std = @import("std");



/// Searches a given array for a given value and returns the index of the first element that matches or null if no element matches.
pub fn contains(comptime T: type, haystack: []T, needle: T) ?usize {
    return for (haystack, 0..) |element, index| {
        if (std.mem.eql(@TypeOf(element[0]), element, needle)) break index;
    }
    else null;
}
