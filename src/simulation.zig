const std = @import("std");
const Cell = @import("./cell.zig").Cell;
const Point = @import("./point.zig").Point;

const PrintOptions = struct {
    newlines: bool,
    from: Point(i32),
    to: Point(i32),
};

pub const Simulation = struct {
    current: std.AutoHashMap(Point(i32), Cell),
    buffer: std.AutoHashMap(Point(i32), Cell),

    const Self = @This();

    pub fn new(allocator: std.mem.Allocator) Self {
        return Simulation{
            .current = std.AutoHashMap(Point(i32), Cell).init(allocator),
            .buffer = std.AutoHashMap(Point(i32), Cell).init(allocator),
        };
    }

    pub fn deinit(this: *Self) void {
        this.current.deinit();
        this.buffer.deinit();
    }

    pub fn spawn(this: *Self, points: []const Point(i32), at: Point(i32)) !void {
        for (points) |point| {
            try this.current.put(point.add(at), Cell.alive);
        }
    }

    pub fn generate(this: *Self, source: std.Random, from: Point(i32), to: Point(i32)) !void {
        for (0..@intCast(to.y)) |y| {
            for (0..@intCast(to.x)) |x| {
                const px: i32 = @intCast(x);
                const py: i32 = @intCast(y);
                const point = Point(i32){ .x = px + from.x, .y = py + from.y };

                if (source.boolean()) {
                    try this.current.put(point, Cell.alive);
                }
            }
        }
    }

    pub fn isEmpty(this: Self) bool {
        return this.current.count() == 0;
    }

    pub fn clear(this: *Self) void {
        this.current.clearRetainingCapacity();
    }

    pub fn tick(this: *Self, from: Point(i32), to: Point(i32)) !void {
        for (0..@intCast(to.y)) |y| {
            for (0..@intCast(to.x)) |x| {
                const px: i32 = @intCast(x);
                const py: i32 = @intCast(y);

                const point = Point(i32){ .x = px + from.x, .y = py + from.y };
                const cell = this.current.get(point) orelse Cell.dead;

                var neighbour_count: i32 = 0;
                for (point.neighbours()) |neighbour| {
                    const neighbour_cell = this.current.get(neighbour) orelse Cell.dead;
                    neighbour_count = switch (neighbour_cell) {
                        Cell.alive => neighbour_count + 1,
                        Cell.dead => neighbour_count,
                    };
                }

                const new_cell = switch (cell) {
                    Cell.alive => switch (neighbour_count) {
                        2...3 => Cell.alive,
                        else => Cell.dead,
                    },
                    Cell.dead => switch (neighbour_count) {
                        3 => Cell.alive,
                        else => Cell.dead,
                    },
                };
                if (new_cell != Cell.dead) {
                    try this.buffer.put(point, new_cell);
                }
            }
        }

        std.mem.swap(@TypeOf(this.current), &this.current, &this.buffer);
        this.buffer.clearRetainingCapacity();
    }

    pub fn print(this: Self, writer: *std.Io.Writer, options: PrintOptions) !void {
        const eol = if (options.newlines) "\n" else "";
        for (0..@intCast(options.to.y)) |y| {
            for (0..@intCast(options.to.x)) |x| {
                const px: i32 = @intCast(x);
                const py: i32 = @intCast(y);

                const cell = this.current.get(Point(i32){
                    .x = px + options.from.x,
                    .y = py + options.from.y,
                }) orelse Cell.dead;

                _ = try switch (cell) {
                    Cell.alive => writer.write("■"),
                    Cell.dead => writer.write(" "),
                };
            }
            _ = try writer.write(eol);
        }
    }
};

test "Simulation: starts empty" {
    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();

    try std.testing.expect(sim.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), sim.current.count());
}

test "Simulation: single live cell dies by underpopulation" {
    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();

    const from = Point(i32){ .x = 0, .y = 0 };
    const size = Point(i32){ .x = 5, .y = 5 };

    try sim.current.put(Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    try sim.tick(from, size);

    try std.testing.expect(sim.isEmpty());
}

test "Simulation: Verify print simple generation" {
    var screen_buffer = std.io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.current.put(Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\     
        \\     
        \\  ■  
        \\     
        \\     
        \\
        ,
        \\     
        \\     
        \\     
        \\     
        \\     
        \\
        ,
        \\     
        \\     
        \\     
        \\     
        \\     
        \\
    };

    for (generations) |generation| {
        screen_buffer.clearRetainingCapacity();
        try sim.print(&screen_buffer.writer, .{
            .newlines = true,
            .from = from,
            .to = to,
        });
        try std.testing.expectEqualSlices(u8, generation, screen_buffer.written());
        try sim.tick(from, to);
    }
}

test "Simulation: Verify blinker" {
    var screen_buffer = std.io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.current.put(Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 2, .y = 2 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 3, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\     
        \\     
        \\ ■■■ 
        \\     
        \\     
        \\
        ,
        \\     
        \\  ■  
        \\  ■  
        \\  ■  
        \\     
        \\
        ,
        \\     
        \\     
        \\ ■■■ 
        \\     
        \\     
        \\
        ,
        \\     
        \\  ■  
        \\  ■  
        \\  ■  
        \\     
        \\
        ,
    };

    for (generations) |generation| {
        screen_buffer.clearRetainingCapacity();
        try sim.print(&screen_buffer.writer, .{
            .newlines = true,
            .from = from,
            .to = to,
        });
        try std.testing.expectEqualSlices(u8, generation, screen_buffer.written());
        try sim.tick(from, to);
    }
}

test "Simulation: Verify glider" {
    var screen_buffer = std.io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.current.put(Point(i32){ .x = 2, .y = 0 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 2, .y = 1 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 2, .y = 2 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 0, .y = 1 }, Cell.alive);

    const generations = [_][]const u8{
        \\  ■  
        \\■ ■  
        \\ ■■  
        \\     
        \\     
        \\
        ,
        \\ ■   
        \\  ■■ 
        \\ ■■  
        \\     
        \\     
        \\
        ,
        \\  ■  
        \\   ■ 
        \\ ■■■ 
        \\     
        \\     
        \\
        ,
        \\     
        \\ ■ ■ 
        \\  ■■ 
        \\  ■  
        \\     
        \\
        ,
        \\     
        \\   ■ 
        \\ ■ ■ 
        \\  ■■ 
        \\     
        \\
        ,
    };

    for (generations) |generation| {
        screen_buffer.clearRetainingCapacity();
        try sim.print(&screen_buffer.writer, .{
            .newlines = true,
            .from = from,
            .to = to,
        });
        try std.testing.expectEqualSlices(u8, generation, screen_buffer.written());
        try sim.tick(from, to);
    }
}

test "Simulation: Verify block" {
    var screen_buffer = std.io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    var sim = Simulation.new(std.testing.allocator);
    defer sim.deinit();
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.current.put(Point(i32){ .x = 1, .y = 1 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 2, .y = 1 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.current.put(Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\     
        \\ ■■  
        \\ ■■  
        \\     
        \\     
        \\
        ,
        \\     
        \\ ■■  
        \\ ■■  
        \\     
        \\     
        \\
        ,
        \\     
        \\ ■■  
        \\ ■■  
        \\     
        \\     
        \\
        ,
    };

    for (generations) |generation| {
        screen_buffer.clearRetainingCapacity();
        try sim.print(&screen_buffer.writer, .{
            .newlines = true,
            .from = from,
            .to = to,
        });
        try std.testing.expectEqualSlices(u8, generation, screen_buffer.written());
        try sim.tick(from, to);
    }
}
