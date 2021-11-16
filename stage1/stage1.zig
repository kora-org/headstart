const console = @import("console");
const graphics = @import("graphics");
const io = @import("io");
const builtin = @import("builtin");
const uefi = @import("std").os.uefi;

pub var system_table: *uefi.tables.SystemTable = undefined;
pub var boot_services: *uefi.tables.BootServices = undefined;

pub export fn stage1_entry(_system_table: *uefi.tables.SystemTable, _boot_services: *uefi.tables.BootServices) void {
    system_table = _system_table;
    boot_services = _boot_services;
    io.outb(0xe9, 't');
    graphics.initialize();
    console.initialize();
    console.printf("Hello {s} World!", .{ "Bootloader" });
    while (true)
        asm volatile("hlt");
}
