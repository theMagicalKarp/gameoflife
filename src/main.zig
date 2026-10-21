const std = @import("std");
const vaxis = @import("vaxis");
const gameoflife = @import("gameoflife");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const random_source: std.Random.IoSource = .{ .io = io };
    const random = random_source.interface();

    var buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(io, &buffer);
    defer tty.deinit();

    var screen_buffer = std.Io.Writer.Allocating.init(allocator);
    defer screen_buffer.deinit();

    var vx = try vaxis.init(io, allocator, init.environ_map, .{});
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);
    try loop.installResizeHandler();
    defer loop.uninstallResizeHandler();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    var simulation = gameoflife.Simulation.new(allocator);
    defer simulation.deinit();

    while (true) {
        if (try loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) {
                        break;
                    } else if (key.matches('q', .{})) {
                        break;
                    } else if (key.matches('c', .{})) {
                        simulation.clear();
                    } else if (key.matches('g', .{})) {
                        const win = vx.window();
                        const glider = gameoflife.Gliders[
                            random.intRangeLessThan(usize, 0, gameoflife.Gliders.len)
                        ];
                        try simulation.spawn(&glider, gameoflife.Point(i32){
                            .x = random.intRangeLessThan(i32, 0, win.width - 2),
                            .y = random.intRangeLessThan(i32, 0, win.height - 2),
                        });
                    } else if (key.matches('r', .{})) {
                        const win = vx.window();
                        try simulation.generate(
                            random,
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
                            random,
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
        try io.sleep(.fromMilliseconds(30), .awake);
    }
}
