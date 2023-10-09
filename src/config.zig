const std = @import("std");
const uefi = std.os.uefi;
const build_options = @import("build_options");
const utils = @import("utils.zig");
const console = @import("console/flanterm.zig");
const keyboard = @import("keyboard.zig");
const filesystem = @import("filesystem.zig");

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
    console.disableCursor();
    var selected: usize = 0;
    while (true) {
        console.clear();
        try console.print("\n", .{});
        try console.print("  \x1b[92mHeadstart\x1b[0m v{s}\n\n", .{build_options.version});
        for (config.entries, 0..) |entry, i| {
            if (selected == i) {
                try console.print("  \x1b[92m>\x1b[0m {s}\n", .{entry.name});
            } else {
                try console.print("    {s}\n", .{entry.name});
            }
        }
        if (try keyboard.getKey()) |key_event| {
            if (key_event.scan_code.key) |key| {
                switch (key) {
                    .Up => {
                        if (@as(isize, @bitCast(selected)) - 1 < 0)
                            selected = config.entries.len
                        else
                            selected -= 1;
                    },
                    .Down => {
                        if (selected > config.entries.len - 2)
                            selected = 0
                        else
                            selected += 1;
                    },
                    else => {},
                }
            }
            if (key_event.scan_code.char) |key| {
                if (key == '\n') {
                    console.clear();
                    console.enableCursor();
                    try loadKernel(config.entries[selected]);
                    break;
                }
            }
        }
    }
}

pub fn loadKernel(kernel: Config.Entry) !void {
    var kernel_file = try filesystem.open(kernel.kernel);
    var header = try std.elf.Header.read(kernel_file);
    var iterator = header.section_header_iterator(kernel_file);
    std.log.debug("Section headers:");
    while (try iterator.next()) |i|
        std.log.debug("  - {any}", .{i});
    try kernel_file.close();
}
