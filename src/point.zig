const std = @import("std");

pub fn Point(comptime T: type) type {
    return struct {
        x: T,
        y: T,

        const Self = @This();

        pub fn hash(self: Self) u64 {
            var h = std.hash.Wyhash.init(0);
            h.update(std.mem.asBytes(&self.x));
            h.update(std.mem.asBytes(&self.y));
            return h.final();
        }

        pub fn eql(a: Self, b: Self) bool {
            return a.x == b.x and a.y == b.y;
        }

        pub fn format(this: Self, writer: *std.Io.Writer) !void {
            try writer.print("Point({any}, {any})", .{ this.x, this.y });
        }

        pub fn neighbours(this: Self) [8]Self {
            return [8]Self{
                .{ .x = this.x - 1, .y = this.y - 1 },
                .{ .x = this.x, .y = this.y - 1 },
                .{ .x = this.x + 1, .y = this.y - 1 },
                .{ .x = this.x - 1, .y = this.y },
                .{ .x = this.x + 1, .y = this.y },
                .{ .x = this.x - 1, .y = this.y + 1 },
                .{ .x = this.x, .y = this.y + 1 },
                .{ .x = this.x + 1, .y = this.y + 1 },
            };
        }

        pub fn add(this: Self, value: Self) Self {
            return Self{ .x = this.x + value.x, .y = this.y + value.y };
        }
    };
}

test "Point: eql, hash, and format" {
    var p1 = Point(i32){ .x = 3, .y = 4 };
    var p2 = Point(i32){ .x = 3, .y = 4 };
    const p3 = Point(i32){ .x = 4, .y = 3 };

    // eql
    try std.testing.expect(p1.eql(p2));
    try std.testing.expect(!p1.eql(p3));

    // hash (deterministic & equal for equal points)
    const h1 = p1.hash();
    const h2 = p2.hash();
    try std.testing.expectEqual(h1, h2);
    try std.testing.expectFmt("Point(3, 4)", "{f}", .{p1});
    try std.testing.expectFmt("Point(3, 4)", "{f}", .{p2});
    try std.testing.expectFmt("Point(4, 3)", "{f}", .{p3});
}

test "Point: HashMap compatibility" {
    var map = std.AutoHashMap(Point(i32), u32).init(std.testing.allocator);
    defer map.deinit();

    try map.put(Point(i32){ .x = 1, .y = 2 }, 1);
    try map.put(Point(i32){ .x = 2, .y = 3 }, 2);
    try map.put(Point(i32){ .x = -2, .y = 4 }, 3);
    try map.put(Point(i32){ .x = 42, .y = 42 }, 1);
    try map.put(Point(i32){ .x = 42, .y = 42 }, 42);

    try std.testing.expectEqual(map.get(Point(i32){ .x = 1, .y = 2 }), 1);
    try std.testing.expectEqual(map.get(Point(i32){ .x = -2, .y = 4 }), 3);
    try std.testing.expectEqual(map.get(Point(i32){ .x = 2, .y = 3 }), 2);
    try std.testing.expectEqual(map.get(Point(i32){ .x = 2, .y = 1 }), null);
    try std.testing.expectEqual(map.get(Point(i32){ .x = 42, .y = 42 }), 42);
}

test "Point: Test neighbors" {
    try std.testing.expectEqual(
        (Point(i32){ .x = 0, .y = 0 }).neighbours(),
        [8]Point(i32){
            Point(i32){ .x = -1, .y = -1 },
            Point(i32){ .x = 0, .y = -1 },
            Point(i32){ .x = 1, .y = -1 },
            Point(i32){ .x = -1, .y = 0 },
            Point(i32){ .x = 1, .y = 0 },
            Point(i32){ .x = -1, .y = 1 },
            Point(i32){ .x = 0, .y = 1 },
            Point(i32){ .x = 1, .y = 1 },
        },
    );

    try std.testing.expectEqual(
        (Point(i32){ .x = -100, .y = 100 }).neighbours(),
        [8]Point(i32){
            Point(i32){ .x = -101, .y = 99 },
            Point(i32){ .x = -100, .y = 99 },
            Point(i32){ .x = -99, .y = 99 },
            Point(i32){ .x = -101, .y = 100 },
            Point(i32){ .x = -99, .y = 100 },
            Point(i32){ .x = -101, .y = 101 },
            Point(i32){ .x = -100, .y = 101 },
            Point(i32){ .x = -99, .y = 101 },
        },
    );
}
