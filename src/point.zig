const std = @import("std");

pub const Point = struct {
    x: i32,
    y: i32,

    pub fn hash(self: @This()) u64 {
        var h = std.hash.Wyhash.init(0);
        h.update(std.mem.asBytes(&self.x));
        h.update(std.mem.asBytes(&self.y));
        return h.final();
    }

    pub fn eql(a: @This(), b: @This()) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn format(this: @This(), writer: *std.Io.Writer) !void {
        try writer.print("Point({d}, {d})", .{ this.x, this.y });
    }
};

test "Point: eql, hash, and format" {
    var p1 = Point{ .x = 3, .y = 4 };
    var p2 = Point{ .x = 3, .y = 4 };
    const p3 = Point{ .x = 4, .y = 3 };

    // eql
    try std.testing.expect(Point.eql(p1, p2));
    try std.testing.expect(!Point.eql(p1, p3));

    // hash (deterministic & equal for equal points)
    const h1 = p1.hash();
    const h2 = p2.hash();
    try std.testing.expectEqual(h1, h2);
    try std.testing.expectFmt("Point(3, 4)", "{f}", .{p1});
    try std.testing.expectFmt("Point(3, 4)", "{f}", .{p2});
    try std.testing.expectFmt("Point(4, 3)", "{f}", .{p3});
}

test "Point: HashMap compatibility" {
    var map = std.AutoHashMap(Point, u32).init(std.testing.allocator);
    defer map.deinit();

    try map.put(Point{ .x = 1, .y = 2 }, 1);
    try map.put(Point{ .x = 2, .y = 3 }, 2);
    try map.put(Point{ .x = -2, .y = 4 }, 3);
    try map.put(Point{ .x = 42, .y = 42 }, 1);
    try map.put(Point{ .x = 42, .y = 42 }, 42);

    try std.testing.expectEqual(map.get(Point{ .x = 1, .y = 2 }), 1);
    try std.testing.expectEqual(map.get(Point{ .x = -2, .y = 4 }), 3);
    try std.testing.expectEqual(map.get(Point{ .x = 2, .y = 3 }), 2);
    try std.testing.expectEqual(map.get(Point{ .x = 2, .y = 1 }), null);
    try std.testing.expectEqual(map.get(Point{ .x = 42, .y = 42 }), 42);
}
