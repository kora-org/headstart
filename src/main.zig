const std = @import("std");
const uefi = std.os.uefi;
const builtin = @import("builtin");
const console = @import("console/flanterm.zig");
const flanterm = @cImport({
    @cInclude("flanterm/flanterm.h");
    @cInclude("flanterm/backends/fb.h");
});
pub const panic = @import("panic.zig").panic;

var ft: *flanterm.flanterm_context = undefined;

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

pub export fn main() void {
    const boot_services = uefi.system_table.boot_services.?;
    var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;
    _ = boot_services.locateProtocol(&uefi.protocols.GraphicsOutputProtocol.guid, null, @as(*?*anyopaque, @ptrCast(&gop)));

    console.init(gop);
    std.log.info("Headstart version {s}", .{"0.1.0"});
    std.log.info("Compiled with Zig v{}", .{builtin.zig_version});
    std.log.info("All your {s} are belong to us", .{"codebase"});
    console.print("i hate myslfe\n", .{}) catch unreachable;
    @panic("h");
}
