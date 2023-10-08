const uefi = @import("std").os.uefi;
const builtin = @import("builtin");

pub var system_table: *uefi.tables.SystemTable = undefined;
pub var boot_services: *uefi.tables.BootServices = undefined;
pub var runtime_services: *uefi.tables.RuntimeServices = undefined;
pub var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;

pub fn blit(framebuffer: []u8) !void {
    try gop.blt(@ptrCast(framebuffer), .BltBufferToVideo, 0, 0, 0, 0, gop.mode.info.horizontal_resolution, gop.mode.info.vertical_resolution, 0).err();
}

pub fn halt() noreturn {
    while (true) {
        switch (builtin.cpu.arch) {
            .x86_64 => asm volatile ("hlt"),
            .aarch64 => asm volatile ("wfi"),
            else => unreachable,
        }
    }
}

pub fn loadProtocol(comptime T: type) !*T {
    var protocol: *T = undefined;
    try boot_services.locateProtocol(&T.guid, null, @ptrCast(&protocol)).err();
    return protocol;
}

pub fn protocolHandlePair(comptime T: type) type {
    return struct {
        protocol: T,
        handle: uefi.Handle,
    };
}

pub fn openProtocols(comptime T: type) ![]protocolHandlePair(T) {
    var num_handles: usize = 0;
    var handle_buffer: [*]uefi.Handle = undefined;
    try boot_services.locateHandleBuffer(
        .ByProtocol,
        &T.guid,
        null,
        &num_handles,
        &handle_buffer,
    ).err();

    var protocols: []protocolHandlePair(T) = try uefi.pool_allocator.alloc(protocolHandlePair(T), num_handles);

    for (0..num_handles) |handle_num| {
        var protocol: ?*T = null;
        try boot_services.openProtocol(
            handle_buffer[handle_num],
            &T.guid,
            @as(*?*anyopaque, @ptrCast(&protocol)),
            uefi.handle,
            null,
            .{ .by_handle_protocol = true },
        ).err();
        if (protocol) |p| {
            protocols[handle_num].protocol = p.*;
            protocols[handle_num].handle = handle_buffer[handle_num];
        }
    }

    return protocols;
}

pub fn closeProtocols(comptime T: type, protocols: []protocolHandlePair(T)) !void {
    for (0..protocols.len) |protocol| {
        try boot_services.closeProtocol(
            protocols.ptr[protocol].handle,
            &T.guid,
            uefi.handle,
            null,
        ).err();
    }
    uefi.pool_allocator.free(protocols);
}
