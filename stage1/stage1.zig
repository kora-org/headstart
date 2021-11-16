const console = @import("console");
const io = @import("io");
const builtin = @import("builtin");
const uefi = @import("std").os.uefi;

pub export fn stage1_entry(ST: *uefi.tables.SystemTable, BS: *uefi.tables.BootServices) void {
    io.outb(0xe9, 't');
    console.initialize();
    console.puts("Hello Bootloader World!");
    while (true)
        asm volatile("hlt");
}
