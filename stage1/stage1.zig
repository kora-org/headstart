const std = @import("std");
const console = @import("console");
const graphics = @import("graphics");
const filesystem = @import("filesystem");
const io = @import("io");
const builtin = @import("builtin");
const uefi = @import("std").os.uefi;

pub var system_table: *uefi.tables.SystemTable = undefined;
pub var boot_services: *uefi.tables.BootServices = undefined;

pub export fn entry() callconv(.C) void {
    graphics.initialize();
    console.initialize();
    console.disableCursor();
    console.setColor(console.ConsoleColors.Green, null);
    console.puts("Xeptoboot 0.0.1\n\n");
    console.putChar('>');
    console.setColor(console.ConsoleColors.LightGray, null);
    console.puts(" 1\n");
    console.puts("  2\n");
    console.puts("  3\n");
    console.puts("  3\n");
    console.putChar('\n');

    filesystem.initialize();
    io.outb(0xe9, 'a');
    const content = filesystem.readFile("\\test.zzz", 552);
    io.outb(0xe9, 'b');
    console.printf("{any}", .{content});
    io.outb(0xe9, 'c');

    while (true) asm volatile ("hlt");
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    _ = message;
    console.printf("[panic] {s}", .{message});
    while (true) asm volatile ("hlt");
    unreachable;
}
