const std = @import("std");
pub const Cell = @import("cell.zig").Cell;
pub const Gliders = @import("cell.zig").Gliders;
pub const Point = @import("point.zig").Point;
pub const Simulation = @import("simulation.zig").Simulation;

test "visit all decls so their tests are found" {
    std.testing.refAllDecls(@This());
}
