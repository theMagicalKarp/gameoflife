const std = @import("std");
const Cell = @import("./cell.zig").Cell;
const Point = @import("./point.zig").Point;

const PrintOptions = struct {
    newlines: bool,
    from: Point(i32),
    to: Point(i32),
};

pub const Simulation = struct {
    cells: std.AutoArrayHashMapUnmanaged(Point(i32), Cell) = .empty,
    buffer: std.AutoArrayHashMapUnmanaged(Point(i32), Cell) = .empty,
    /// Scratch space for live-neighbour counts during `tick`.
    counts: std.AutoArrayHashMapUnmanaged(Point(i32), u8) = .empty,

    const Self = @This();

    pub const empty: Self = .{};

    pub fn deinit(this: *Self, gpa: std.mem.Allocator) void {
        this.cells.deinit(gpa);
        this.buffer.deinit(gpa);
        this.counts.deinit(gpa);
    }

    pub fn spawn(this: *Self, gpa: std.mem.Allocator, points: []const Point(i32), at: Point(i32)) !void {
        for (points) |point| {
            try this.cells.put(gpa, point.add(at), Cell.alive);
        }
    }

    pub fn generate(this: *Self, gpa: std.mem.Allocator, source: std.Random, from: Point(i32), size: Point(i32)) !void {
        for (0..@intCast(size.y)) |y| {
            for (0..@intCast(size.x)) |x| {
                const px: i32 = @intCast(x);
                const py: i32 = @intCast(y);
                const point = Point(i32){ .x = px + from.x, .y = py + from.y };

                if (source.boolean()) {
                    try this.cells.put(gpa, point, Cell.alive);
                }
            }
        }
    }

    pub fn isEmpty(this: Self) bool {
        return this.cells.count() == 0;
    }

    pub fn clear(this: *Self) void {
        this.cells.clearRetainingCapacity();
    }

    /// Advances one generation. Only cells inside the `size` region starting at `from` survive or
    /// are born; anything outside it is discarded. Work scales with live cells, not region area.
    pub fn tick(this: *Self, gpa: std.mem.Allocator, from: Point(i32), size: Point(i32)) !void {
        this.counts.clearRetainingCapacity();
        this.buffer.clearRetainingCapacity();
        for (this.cells.keys()) |point| {
            for (point.neighbours()) |neighbour| {
                const count = try this.counts.getOrPut(gpa, neighbour);
                count.value_ptr.* = switch (count.found_existing) {
                    true => count.value_ptr.* + 1,
                    false => 1,
                };
            }
        }

        for (this.counts.keys(), this.counts.values()) |point, neighbour_count| {
            if (point.x < from.x or point.x >= from.x + size.x) {
                continue;
            }
            if (point.y < from.y or point.y >= from.y + size.y) {
                continue;
            }

            const cell = this.cells.get(point) orelse Cell.dead;
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
                try this.buffer.put(gpa, point, new_cell);
            }
        }

        std.mem.swap(@TypeOf(this.cells), &this.cells, &this.buffer);
    }

    pub fn print(this: Self, writer: *std.Io.Writer, options: PrintOptions) !void {
        const eol = if (options.newlines) "\n" else "";
        for (0..@intCast(options.to.y)) |y| {
            for (0..@intCast(options.to.x)) |x| {
                const px: i32 = @intCast(x);
                const py: i32 = @intCast(y);

                const cell = this.cells.get(Point(i32){
                    .x = px + options.from.x,
                    .y = py + options.from.y,
                }) orelse Cell.dead;

                _ = try switch (cell) {
                    Cell.alive => writer.write("██"),
                    Cell.dead => writer.write("  "),
                };
            }
            _ = try writer.write(eol);
        }
    }
};

test "Simulation: starts empty" {
    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);

    try std.testing.expect(sim.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), sim.cells.count());
}

test "Simulation: single live cell dies by underpopulation" {
    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);

    const from = Point(i32){ .x = 0, .y = 0 };
    const size = Point(i32){ .x = 5, .y = 5 };

    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    try sim.tick(gpa, from, size);

    try std.testing.expect(sim.isEmpty());
}

test "Simulation: Verify print simple generation" {
    var screen_buffer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\          
        \\          
        \\    ██    
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
        try sim.tick(gpa, from, to);
    }
}

test "Simulation: Verify blinker" {
    var screen_buffer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.cells.put(gpa, Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 3, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\          
        \\          
        \\  ██████  
        \\          
        \\          
        \\
        ,
        \\          
        \\    ██    
        \\    ██    
        \\    ██    
        \\          
        \\
        ,
        \\          
        \\          
        \\  ██████  
        \\          
        \\          
        \\
        ,
        \\          
        \\    ██    
        \\    ██    
        \\    ██    
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
        try sim.tick(gpa, from, to);
    }
}

test "Simulation: Verify glider" {
    var screen_buffer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 0 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 1 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 0, .y = 1 }, Cell.alive);

    const generations = [_][]const u8{
        \\    ██    
        \\██  ██    
        \\  ████    
        \\          
        \\          
        \\
        ,
        \\  ██      
        \\    ████  
        \\  ████    
        \\          
        \\          
        \\
        ,
        \\    ██    
        \\      ██  
        \\  ██████  
        \\          
        \\          
        \\
        ,
        \\          
        \\  ██  ██  
        \\    ████  
        \\    ██    
        \\          
        \\
        ,
        \\          
        \\      ██  
        \\  ██  ██  
        \\    ████  
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
        try sim.tick(gpa, from, to);
    }
}

test "Simulation: Verify block" {
    var screen_buffer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);
    const from = Point(i32){ .x = 0, .y = 0 };
    const to = Point(i32){ .x = 5, .y = 5 };

    try sim.cells.put(gpa, Point(i32){ .x = 1, .y = 1 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 1 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 1, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 2, .y = 2 }, Cell.alive);

    const generations = [_][]const u8{
        \\          
        \\  ████    
        \\  ████    
        \\          
        \\          
        \\
        ,
        \\          
        \\  ████    
        \\  ████    
        \\          
        \\          
        \\
        ,
        \\          
        \\  ████    
        \\  ████    
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
        try sim.tick(gpa, from, to);
    }
}

test "Simulation: cells outside the visible area keep simulating" {
    var screen_buffer = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer screen_buffer.deinit();

    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);
    const view_from = Point(i32){ .x = 0, .y = 0 };
    const view_size = Point(i32){ .x = 5, .y = 5 };
    const sim_from = Point(i32){ .x = -10, .y = -10 };
    const sim_size = Point(i32){ .x = 25, .y = 25 };

    // Glider just above-left of the view, heading down-right into it.
    try sim.cells.put(gpa, Point(i32){ .x = -3, .y = -5 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = -2, .y = -4 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = -4, .y = -3 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = -3, .y = -3 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = -2, .y = -3 }, Cell.alive);

    for (0..20) |_| try sim.tick(gpa, sim_from, sim_size);

    // After 20 generations it has moved (+5, +5) and is fully on screen.
    try sim.print(&screen_buffer.writer, .{ .newlines = true, .from = view_from, .to = view_size });
    try std.testing.expectEqualSlices(u8,
        \\    ██    
        \\      ██  
        \\  ██████  
        \\          
        \\          
        \\
    , screen_buffer.written());
}

test "Simulation: cells beyond the simulated area are discarded" {
    const gpa = std.testing.allocator;
    var sim: Simulation = .empty;
    defer sim.deinit(gpa);

    // Block straddling the right edge of the region is clipped and dies off.
    try sim.cells.put(gpa, Point(i32){ .x = 4, .y = 1 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 5, .y = 1 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 4, .y = 2 }, Cell.alive);
    try sim.cells.put(gpa, Point(i32){ .x = 5, .y = 2 }, Cell.alive);

    try sim.tick(gpa, Point(i32){ .x = 0, .y = 0 }, Point(i32){ .x = 5, .y = 5 });
    try std.testing.expect(sim.cells.get(Point(i32){ .x = 5, .y = 1 }) == null);
}
