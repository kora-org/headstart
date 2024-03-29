const std = @import("std");
const uefi = std.os.uefi;
const builtin = @import("builtin");
const build_options = @import("build_options");
const utils = @import("utils.zig");
const console = @import("console/flanterm.zig");
const keyboard = @import("keyboard.zig");
const memmap = @import("memmap.zig");
const filesystem = @import("filesystem.zig");
const config = @import("config.zig");
pub const panic = @import("panic.zig").panic;

pub const std_options = struct {
    pub fn logFn(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
        const scope_prefix = if (scope == .default) "main" else @tagName(scope);
        const prefix = "\x1b[32m[headstart:" ++ scope_prefix ++ "] " ++ switch (level) {
            .err => "\x1b[31merror",
            .warn => "\x1b[33mwarning",
            .info => "\x1b[36minfo",
            .debug => "\x1b[90mdebug",
        } ++ ": \x1b[0m";
        console.print(prefix ++ format ++ "\n", args) catch unreachable;
    }
};

pub fn main() uefi.Status {
    return efi_main() catch |err| @panic(@errorName(err));
}

pub fn efi_main() !uefi.Status {
    utils.system_table = uefi.system_table;
    utils.boot_services = uefi.system_table.boot_services.?;
    utils.runtime_services = uefi.system_table.runtime_services;
    utils.gop = try utils.loadProtocol(uefi.protocols.GraphicsOutputProtocol);
    console.init();
    try keyboard.init();
    try filesystem.init();

    std.log.info("\x1b[96mHeadstart\x1b[0m version {s}", .{build_options.version});
    std.log.info("Compiled with Zig v{}", .{builtin.zig_version});
    std.log.info("All your {s} are belong to us", .{"codebase"});
    try console.print("i hate myslfe\n", .{});

    try memmap.memmap.init();
    std.log.debug("Memory map layout:", .{});
    for (memmap.memmap.entries) |entry|
        std.log.debug("  base=0x{x:0>16}, length=0x{x:0>16}, type={s}", .{ entry.base, entry.length, @tagName(entry.type) });

    var config_file = try filesystem.open("/headstart.json");
    var contents = try config_file.reader().readAllAlloc(uefi.pool_allocator, @intCast(try config_file.getSize()));
    try config_file.close();

    var serialized = try std.json.parseFromSlice(config.Config, uefi.pool_allocator, contents, .{});
    defer serialized.deinit();
    try config.showMenu(serialized.value);

    unreachable;
}

export fn __chkstk() void {}
