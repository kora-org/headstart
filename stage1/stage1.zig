const std = @import("std");
const console = @import("console");
const graphics = @import("graphics");
const filesystem = @import("filesystem");
const io = @import("io");
const builtin = @import("builtin");
const uefi = @import("std").os.uefi;
const mem = @import("std").mem;
const zzz = @import("zzz");

pub var system_table: *uefi.tables.SystemTable = undefined;
pub var boot_services: *uefi.tables.BootServices = undefined;

pub export fn entry() callconv(.C) void {
    graphics.initialize();
    console.initialize();
    console.disableCursor();
    console.setColor(console.ConsoleColors.Green, null);
    console.printf("Xeptoboot {s}\n\n", .{"0.0.1"});
    console.putChar('>');
    console.setColor(console.ConsoleColors.LightGray, null);
    console.puts(" 1\n");
    console.puts("  2\n");
    console.puts("  3\n");
    console.puts("  3\n");
    console.putChar('\n');

    filesystem.initialize();
    io.outb(0xe9, 'a');
    const content = filesystem.readFile("\\xeptoboot.zzz");
    io.outb(0xe9, 'b');

    var path = mem.split(u8, "1::2::3", "::");
    console.printf("{s} {s}\n", .{ path.next(), path.rest() });

    var tree = zzz.ZTree(1, 1024){};
    var node = tree.appendText(content) catch unreachable;

    _ = tree;
    _ = node;
    //var depth: isize = 0;
    //var iter = node;
    //while (iter.nextUntil(node, &depth)) |c| : (iter = c) {
    //    var i: isize = 0;
    //    while (i < depth) : (i += 1) {
    //        console.printf("  ", .{});
    //    }
    //    console.printf("{}\n", .{c.value});
    //}

    io.outb(0xe9, 'c');

    while (true) asm volatile ("hlt");
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    console.printf("[panic] {s}", .{message});
    while (true) asm volatile ("hlt");
    unreachable;
}
