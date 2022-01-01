const std = @import("std");
const uefi = @import("std").os.uefi;
const console = @import("console");
const builtin = @import("builtin");
const stage1 = @import("../stage1.zig");

pub fn toUtf16(comptime ascii: []const u8) [ascii.len:0]u16 {
    const curr = [1:0]u16{ascii[0]};
    if (ascii.len == 1) return curr;
    return curr ++ toUtf16(ascii[1..]);
}

pub fn main() void {
    stage1.system_table = uefi.system_table;
    stage1.boot_services = uefi.system_table.boot_services.?;
    console.con_out = uefi.system_table.con_out.?;
    // Set UEFI firmware watchdog to infinite so it won't reboot within 5 minutes
    _ = stage1.boot_services.setWatchdogTimer(0, 0, 0, null);
    stage1.entry();

    while (true) asm volatile ("hlt");
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    stage1.panic(message, null);
}
