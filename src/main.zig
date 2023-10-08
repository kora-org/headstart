const std = @import("std");
const uefi = std.os.uefi;
const builtin = @import("builtin");
const utils = @import("utils.zig");
const console = @import("console/flanterm.zig");
const memmap = @import("memmap.zig");
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

    std.log.info("Headstart version {s}", .{"0.1.0"});
    std.log.info("Compiled with Zig v{}", .{builtin.zig_version});
    std.log.info("All your {s} are belong to us", .{"codebase"});
    console.print("i hate myslfe\n", .{}) catch unreachable;
    try memmap.init();
    try memmap.memmap.minify();
    std.log.debug("Memory map layout:", .{});
    for (memmap.memmap.entries) |entry|
        std.log.debug("  base=0x{x:0>16}, length=0x{x:0>16}, type={s}", .{ entry.base, entry.length, @tagName(entry.type) });
    @panic("h");
}

export fn __chkstk() void {}
