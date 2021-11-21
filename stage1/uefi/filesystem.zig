const stage1 = @import("../stage1.zig");
const uefi = @import("std").os.uefi;

pub fn read_file(file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    var result = file.setPosition(position);
    if (result != uefi.Status.Success) { return result; }

    return file.read(&@ptrCast(usize, size), buffer.*);
}

pub fn read_and_allocate(file: *uefi.protocols.FileProtocol, position: u64, size: usize, buffer: *[*]align(8) u8) uefi.Status {
    var result = stage1.boot_services.allocatePool(uefi.tables.MemoryType.LoaderData, size, buffer);
    if (result != uefi.Status.Success) { return result; }

    return read_file(file, position, size, buffer);
}
