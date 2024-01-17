const std = @import("std");
const chameleon = @import("chameleon");

const lexer = @import("Lexer.zig");
const io = @import("io.zig");

pub fn main() !void {
    const cham = comptime chameleon.Chameleon.init(.Auto);

    var ha = std.heap.HeapAllocator.init();
    defer ha.deinit();
    const allocator = ha.allocator();

    const tokens = try lexer.tokenizeFile(allocator, "test.qk");
    defer allocator.free(tokens);

    for (tokens, 1..) |t, i| {
        try io.print("[" ++ cham.yellow().fmt("{d:0>2}") ++ "] = " ++ cham.red().fmt("{any}") ++ "\n", .{ i, t });
    }
}
