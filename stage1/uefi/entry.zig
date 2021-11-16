const uefi = @import("std").os.uefi;
const console = @import("console");
const stage1 = @import("../stage1.zig");

pub fn main() void {
    const system_table = uefi.system_table;
    const boot_services = uefi.system_table.boot_services.?;
    console.con_out = uefi.system_table.con_out.?;
    stage1.stage1_entry(system_table, boot_services);
}
