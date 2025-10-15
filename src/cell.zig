const std = @import("std");
pub const Point = @import("point.zig").Point;

pub const Cell = enum {
    alive,
    dead,

    const Self = @This();

    pub fn format(this: Self, writer: *std.Io.Writer) !void {
        try switch (this) {
            .alive => writer.print("Cell(alive)", .{}),
            .dead => writer.print("Cell(dead)", .{}),
        };
    }
};

pub const Gliders = [_][5]Point(i32){
    .{
        Point(i32){ .x = 1, .y = -1 },
        Point(i32){ .x = 1, .y = 0 },
        Point(i32){ .x = 1, .y = 1 },
        Point(i32){ .x = 0, .y = 1 },
        Point(i32){ .x = -1, .y = -1 },
    },
    .{
        Point(i32){ .x = -1, .y = -1 },
        Point(i32){ .x = -1, .y = 0 },
        Point(i32){ .x = -1, .y = 1 },
        Point(i32){ .x = 0, .y = 1 },
        Point(i32){ .x = 1, .y = -1 },
    },
    .{
        Point(i32){ .x = 1, .y = -1 },
        Point(i32){ .x = 0, .y = -1 },
        Point(i32){ .x = -1, .y = -1 },
        Point(i32){ .x = -1, .y = 0 },
        Point(i32){ .x = 1, .y = 1 },
    },
    .{
        Point(i32){ .x = -1, .y = -1 },
        Point(i32){ .x = 0, .y = -1 },
        Point(i32){ .x = 1, .y = -1 },
        Point(i32){ .x = 1, .y = 0 },
        Point(i32){ .x = -1, .y = 1 },
    },
};

test "Cell: validate formatting" {
    try std.testing.expectFmt("Cell(dead)", "{f}", .{Cell.dead});
    try std.testing.expectFmt("Cell(alive)", "{f}", .{Cell.alive});
}
