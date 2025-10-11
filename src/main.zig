const std = @import("std");
const gameoflife = @import("gameoflife");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    const x = gameoflife.Point{ .x = 1, .y = 2 };
    std.debug.print("{f}\n", .{x});
    try gameoflife.bufferedPrint();

    var map = std.AutoHashMap(gameoflife.Point, u32).init(allocator);
    defer map.deinit();
    try map.put(x, 1);
    const result = map.get(gameoflife.Point{ .x = 1, .y = 2 }) orelse 0;
    const result2 = map.get(gameoflife.Point{ .x = 2, .y = 2 }) orelse 0;

    std.debug.print("{d}\n", .{result});
    std.debug.print("{d}\n", .{result2});
}
