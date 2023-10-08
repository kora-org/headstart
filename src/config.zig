const std = @import("std");
const uefi = std.os.uefi;
const build_options = @import("build_options");
const utils = @import("utils.zig");
const console = @import("console/flanterm.zig");

pub const Config = struct {
    resolution: ?[]const u8,
    entries: []Entry,

    pub const Entry = struct {
        name: []const u8,
        kernel: []const u8,
        protocol: []const u8,
        cmdline: ?[]const u8 = null,
        modules: ?[]Module = null,
    };

    pub const Module = struct {
        name: []const u8,
        module: []const u8,
    };
};

pub fn showMenu(config: Config) !void {
    console.clear();
    try console.print("\n", .{});
    try console.print("  \x1b[92mHeadstart\x1b[0m v{s}\n\n", .{build_options.version});
    for (config.entries, 0..) |entry, i| {
        if (i == 0) {
            try console.print("  \x1b[92m>\x1b[0m {s}\n", .{entry.name});
        } else {
            try console.print("    {s}\n", .{entry.name});
        }
    }
}
