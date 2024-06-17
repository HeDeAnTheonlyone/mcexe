
const std = @import("std");

const ArrayList = std.ArrayList;



/// Searches a given array for a given value and returns the index of the first matching element or null if no element matches.
pub fn contains(comptime T: type, haystack: []T, needle: T) ?usize {
    return for (haystack, 0..) |element, index| {
        if (std.mem.eql(@TypeOf(element[0]), element, needle)) break index;
    }
    else null;
}

/// Searches a given array for any value in a second given array and returns the index of the first matching element or null if no element matches.
pub fn containsAny(comptime T: type, haystack: []T, needles: []const T) ?usize {
    return outer: for (haystack, 0..) |element, index| {
        for (needles) |needle| {
            if (std.mem.eql(@TypeOf(element[0]), element, needle)) break :outer index;
        }
    }
    else null;
}

/// Returns a slice of newly allocated data without the scalar value
pub fn removeScalar(comptime T: type, allocator: std.mem.Allocator, buffer: []T, scalar: T) ![]const u8 {
    const count = std.mem.count(T, buffer, &[1]T{scalar});
    const clean_str = try allocator.alloc(T, buffer.len - count);
    var i: usize = 0;
    for (buffer) |char| {
        if (char != scalar) {
            clean_str[i] = char;
            i += 1;
        }
    }
    return clean_str;
}
