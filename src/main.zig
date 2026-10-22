const std = @import("std");
const vaxis = @import("vaxis");
const gameoflife = @import("gameoflife");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    mouse: vaxis.Mouse,
    focus_in,
};

/// Simulation generations per second, ordered slowest to fastest.
const step_rates = [_]u32{ 1, 2, 4, 8, 15, 30, 60 };
const default_speed = 5;

/// How often the screen is redrawn and input is processed, independent of simulation speed.
const frame_interval: std.Io.Duration = .fromMilliseconds(15);

/// Cells keep simulating this far past each edge of the screen before being discarded.
const offscreen_margin = 100;

/// Each cell is drawn two terminal columns wide so it appears roughly square.
const cell_width = 2;

/// The number of cells visible inside the border.
fn boardSize(win: vaxis.Window) gameoflife.Point(i32) {
    return .{
        .x = @divTrunc(@max(@as(i32, win.width) - 2, 0), cell_width),
        .y = @max(@as(i32, win.height) - 2, 0),
    };
}

/// The region that is simulated: the board inside the border plus `offscreen_margin` on every side.
fn simulatedArea(win: vaxis.Window) struct { from: gameoflife.Point(i32), size: gameoflife.Point(i32) } {
    const board = boardSize(win);
    return .{
        .from = .{ .x = -offscreen_margin, .y = -offscreen_margin },
        .size = .{
            .x = board.x + 2 * offscreen_margin,
            .y = board.y + 2 * offscreen_margin,
        },
    };
}

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
    try vx.setMouseMode(tty.writer(), true);

    var simulation: gameoflife.Simulation = .empty;
    defer simulation.deinit(allocator);

    var paused = false;
    var speed: usize = default_speed;
    var next_step = std.Io.Timestamp.now(io, .awake);

    main_loop: while (true) {
        // Drain every pending event so fast mouse drags don't back up the queue.
        while (try loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('c', .{ .ctrl = true })) {
                        break :main_loop;
                    } else if (key.matches('q', .{})) {
                        break :main_loop;
                    } else if (key.matches('c', .{})) {
                        simulation.clear();
                    } else if (key.matches('g', .{})) {
                        const board = boardSize(vx.window());
                        if (board.x <= 0 or board.y <= 0) {
                            continue;
                        }
                        const glider = gameoflife.Gliders[
                            random.intRangeLessThan(usize, 0, gameoflife.Gliders.len)
                        ];
                        try simulation.spawn(allocator, &glider, gameoflife.Point(i32){
                            .x = random.intRangeLessThan(i32, 0, board.x),
                            .y = random.intRangeLessThan(i32, 0, board.y),
                        });
                    } else if (key.matches(' ', .{})) {
                        paused = !paused;
                    } else if (key.matches(vaxis.Key.right, .{})) {
                        speed = @min(speed + 1, step_rates.len - 1);
                    } else if (key.matches(vaxis.Key.left, .{})) {
                        speed -|= 1;
                    } else if (key.matches('r', .{})) {
                        const win = vx.window();
                        const area = simulatedArea(win);
                        try simulation.generate(allocator, random, area.from, area.size);
                    }
                },
                .mouse => |mouse| {
                    if (mouse.button == .left and (mouse.type == .press or mouse.type == .drag)) {
                        const single_cell = [1]gameoflife.Point(i32){
                            gameoflife.Point(i32){ .x = 0, .y = 0 },
                        };

                        // Offset by 1 to account for the border around the simulation window.
                        try simulation.spawn(allocator, &single_cell, gameoflife.Point(i32){
                            .x = @divFloor(@as(i32, mouse.col) - 1, cell_width),
                            .y = @as(i32, mouse.row) - 1,
                        });
                    }
                },

                .winsize => |ws| {
                    try vx.resize(allocator, tty.writer(), ws);

                    if (simulation.isEmpty()) {
                        const win = vx.window();
                        const area = simulatedArea(win);
                        try simulation.generate(allocator, random, area.from, area.size);
                    }
                },
                else => {},
            }
        }

        const win = vx.window();
        win.clear();

        // Cyan while running, yellow while paused.
        const accent: vaxis.Color = .{ .index = if (paused) 3 else 6 };

        const child = win.child(.{
            .x_off = 0,
            .y_off = 0,
            .width = win.width,
            .height = win.height,
            .border = .{
                .where = .all,
                .style = .{
                    .fg = accent,
                },
            },
        });

        screen_buffer.clearRetainingCapacity();
        const from = gameoflife.Point(i32){ .x = 0, .y = 0 };
        const to = boardSize(win);

        const area = simulatedArea(win);

        const now = std.Io.Timestamp.now(io, .awake);
        if (paused) {
            next_step = now;
        } else if (now.durationTo(next_step).nanoseconds <= 0) {
            try simulation.tick(allocator, area.from, area.size);
            // Schedule from the previous deadline so frame jitter doesn't drag the rate below target.
            next_step = next_step.addDuration(.fromNanoseconds(std.time.ns_per_s / step_rates[speed]));
            if (next_step.durationTo(now).nanoseconds > 0) {
                next_step = now;
            }
        }
        try simulation.print(&screen_buffer.writer, .{
            .newlines = false,
            .from = from,
            .to = to,
        });

        // Size the board to a whole number of cells so each row wraps exactly at its last cell.
        const board = child.child(.{
            .width = @intCast(to.x * cell_width),
            .height = @intCast(to.y),
        });
        _ = board.printSegment(.{ .text = screen_buffer.written() }, .{ .wrap = .grapheme });

        // Overlay the status line on the bottom border so it doesn't shrink the board.
        var status_buffer: [256]u8 = undefined;
        const status = std.fmt.bufPrint(
            &status_buffer,
            " {d:>2} fps │ space pause · ←/→ speed · g glider · r reset · c clear · q quit ",
            .{step_rates[speed]},
        ) catch "";
        if (win.width > 4 and win.height > 0) {
            const status_bar = win.child(.{
                .x_off = 2,
                .y_off = @intCast(win.height - 1),
                .width = win.width - 4,
                .height = 1,
            });
            _ = status_bar.printSegment(.{
                .text = status,
                .style = .{ .fg = accent },
            }, .{ .wrap = .none });
        }

        // Center the pause label on the top border so the status line never shifts.
        const pause_label = " PAUSED ";
        if (paused and win.width >= pause_label.len + 2) {
            const pause_bar = win.child(.{
                .x_off = @intCast((win.width - pause_label.len) / 2),
                .y_off = 0,
                .width = pause_label.len,
                .height = 1,
            });
            _ = pause_bar.printSegment(.{
                .text = pause_label,
                .style = .{ .fg = accent, .bold = true },
            }, .{ .wrap = .none });
        }

        try vx.render(tty.writer());
        try io.sleep(frame_interval, .awake);
    }
}
