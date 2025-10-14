const std = @import("std");
const vaxis = @import("vaxis");
const gameoflife = @import("gameoflife");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(&buffer);
    defer tty.deinit();

    var screen_buffer = std.io.Writer.Allocating.init(allocator);
    defer screen_buffer.deinit();

    var vx = try vaxis.init(allocator, .{});
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .{ .tty = &tty, .vaxis = &vx };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), 1 * std.time.ns_per_s);

    var simulation = gameoflife.Simulation.new(allocator);
    defer simulation.deinit();

    while (true) {
        if (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) {
                        break;
                    } else if (key.matches('q', .{})) {
                        break;
                    } else if (key.matches('r', .{})) {
                        const win = vx.window();
                        try simulation.generate(
                            std.crypto.random,
                            gameoflife.Point(i32){ .x = 0, .y = 0 },
                            gameoflife.Point(i32){ .x = win.width - 2, .y = win.height - 2 },
                        );
                    }
                },

                .winsize => |ws| {
                    try vx.resize(allocator, tty.writer(), ws);

                    if (simulation.isEmpty()) {
                        const win = vx.window();
                        try simulation.generate(
                            std.crypto.random,
                            gameoflife.Point(i32){ .x = 0, .y = 0 },
                            gameoflife.Point(i32){ .x = win.width - 2, .y = win.height - 2 },
                        );
                    }
                },
                else => {},
            }
        }

        const win = vx.window();
        win.clear();

        const child = win.child(.{
            .x_off = 0,
            .y_off = 0,
            .width = win.width,
            .height = win.height,
            .border = .{
                .where = .all,
                .style = .{
                    .fg = .{ .index = 6 },
                },
            },
        });

        screen_buffer.clearRetainingCapacity();
        const from = gameoflife.Point(i32){ .x = 0, .y = 0 };
        const to = gameoflife.Point(i32){ .x = win.width - 2, .y = win.height - 2 };

        try simulation.tick(from, to);
        try simulation.print(&screen_buffer.writer, .{
            .newlines = false,
            .from = from,
            .to = to,
        });

        _ = child.printSegment(.{ .text = screen_buffer.written() }, .{ .wrap = .grapheme });
        try vx.render(tty.writer());
        std.Thread.sleep(30 * std.time.ns_per_ms);
    }
}
