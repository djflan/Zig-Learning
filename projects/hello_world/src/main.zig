//const std = @import("std");
const prj_hello_world = @import("prj_hello_world");
const std = prj_hello_world.std;

pub fn main() !void {
    try std.fs.File.stdout().writeAll("Hello, World!\n");
}
