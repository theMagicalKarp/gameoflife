const std = @import("std");

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

test "Cell: validate formatting" {
    try std.testing.expectFmt("Cell(dead)", "{f}", .{Cell.dead});
    try std.testing.expectFmt("Cell(alive)", "{f}", .{Cell.alive});
}
