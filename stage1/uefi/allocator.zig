const std = @import("std");
const stage1 = @import("../stage1.zig");
const uefi = @import("std").os.uefi;
const mem = @import("std").mem;
const Allocator = @import("std").mem.Allocator;

fn alloc(_: *anyopaque, len: usize, ptr_align: u29, len_align: u29, ret_addr: usize) Allocator.Error![]u8 {
    _ = len_align;
    _ = ret_addr;

    std.debug.assert(ptr_align <= 8);

    var ptr: [*]align(8) u8 = undefined;

    if (stage1.system_table.boot_services.?.allocatePool(
        .BootServicesData,
        len,
        &ptr,
    ) != .Success) {
        return error.OutOfMemory;
    }

    return ptr[0..len];
}

fn resize(_: *anyopaque, buf: []u8, old_align: u29, new_len: usize, len_align: u29, ret_addr: usize) ?usize {
    _ = old_align;
    _ = ret_addr;

    if (new_len == 0) {
        free(undefined, buf, old_align, ret_addr);
        return 0;
    }

    if (new_len <= buf.len) {
        return mem.alignAllocLen(buf.len, new_len, len_align);
    }

    return null;
}

fn free(_: *anyopaque, buf: []u8, old_align: u29, ret_addr: usize) void {
    _ = old_align;
    _ = ret_addr;

    std.debug.assert(old_align == 8);

    _ = stage1.system_table.boot_services.?.freePool(@alignCast(8, buf.ptr));
}

pub const allocator = Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};
