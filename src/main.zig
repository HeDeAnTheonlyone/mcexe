const std = @import("std");
const builtin = @import("builtin");
const lexer = @import("lexer.zig");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    const out = std.io.getStdOut().writer();
    const in = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    
    _ = try out.write("Input Text:\n");
    
    const input_len = try in.read(&buf);

    var status = lexer.LexerStatus.init(buf[0..input_len]);

    while (true) { 
        const token = try lexer.lex(&status);
        if (token.token_type == .Eof) break;

        const tknStr = try std.fmt.allocPrint(gpa, "{s} - {any}\n", .{token.value, token.token_type});
        defer gpa.free(tknStr);
        _ = try out.write(tknStr);
    }
}
