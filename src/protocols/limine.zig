const std = @import("std");
const uefi = std.os.uefi;
const builtin = @import("builtin");
const utils = @import("../utils.zig");
const filesystem = @import("../filesystem.zig");
const memmap = @import("../memmap.zig");
const vmm = @import("../vmm.zig");
const Config = @import("../config.zig").Config;
const limine = @import("limine");

pub const RequestHeader = extern struct {
    /// The ID of the request.
    id: [4]u64,
    /// The revision of the request that the kernel provides.
    revision: u64,
    /// The pointer to the response structure.
    response: ?*anyopaque,
};

pub fn load(kernel: Config.Entry) !void {
    var kernel_file = try filesystem.open(kernel.kernel);
    var buffer = try kernel_file.reader().readAllAlloc(uefi.pool_allocator, @intCast(try kernel_file.getSize()));
    try kernel_file.seekableStream().seekTo(0);
    var header = try std.elf.Header.read(kernel_file);
    if (header.machine.toTargetCpuArch() == builtin.cpu.arch) {
        var min_vaddr: u64 = std.math.maxInt(u64);
        var max_vaddr: u64 = std.math.minInt(u64);
        var bss_size: usize = 0;

        var iterator = header.program_header_iterator(kernel_file);
        while (try iterator.next()) |phdr| {
            if (phdr.p_type == std.elf.PT_LOAD) {
                min_vaddr = @min(min_vaddr, phdr.p_vaddr);
                max_vaddr = @max(max_vaddr, phdr.p_vaddr + phdr.p_memsz);
            }
        }

        const image_size = max_vaddr - min_vaddr;
        var image_base = try uefi.pool_allocator.alloc(u8, image_size);

        iterator = header.program_header_iterator(kernel_file);
        while (try iterator.next()) |phdr| {
            if (phdr.p_type == std.elf.PT_LOAD) {
                const addr = @intFromPtr(image_base.ptr) + (phdr.p_vaddr - min_vaddr);
                @memcpy(@as([*]u8, @ptrFromInt(addr))[0..phdr.p_filesz], @as([*]u8, @ptrCast(buffer))[phdr.p_offset .. phdr.p_offset + phdr.p_filesz]);
                if (phdr.p_memsz > phdr.p_filesz) {
                    @memset(@as([*]u8, @ptrFromInt(addr))[phdr.p_filesz..phdr.p_memsz], 0);
                    bss_size = phdr.p_memsz - phdr.p_filesz;
                }
            }
        }

        var i: usize = 0;
        while (i < std.mem.alignBackward(usize, image_size - bss_size, 8)) : (i += 8) {
            const chunk = @as([*]u64, @ptrFromInt(@intFromPtr(image_base.ptr) + i));
            if (chunk[0] == limine.COMMON_MAGIC[0] and chunk[1] == limine.COMMON_MAGIC[1]) {
                const request_header: *RequestHeader = @ptrCast(chunk);

                if (std.mem.eql(u64, &request_header.id, &limine.Identifiers.Framebuffer)) {
                    var request = @as(*limine.Framebuffer.Request, @ptrCast(chunk));
                    var framebuffer: limine.Framebuffer.Fb = .{
                        .address = utils.gop.mode.frame_buffer_base,
                        .width = utils.gop.mode.info.horizontal_resolution,
                        .height = utils.gop.mode.info.vertical_resolution,
                        .pitch = utils.gop.mode.info.horizontal_resolution * 4,
                        .bpp = 32,
                        .memory_model = .Rgb,
                        // TODO: actually use actual rgb mask size/shift values from gop
                        .red_mask_size = 8,
                        .red_mask_shift = 0,
                        .green_mask_size = 8,
                        .green_mask_shift = 8,
                        .blue_mask_size = 8,
                        .blue_mask_shift = 16,
                        ._unused = "_unused".*,
                        .edid_size = 0,
                        .edid = null,
                        .mode_count = 0,
                        .modes = null,
                    };
                    var framebuffers: [1]*limine.Framebuffer.Fb = .{&framebuffer};
                    var response = limine.Framebuffer.Response{
                        .framebuffer_count = 1,
                        .framebuffers = framebuffers[0..],
                    };
                    request.* = .{ .response = &response };
                } else return error.InvalidRequest;
            }
        }

        //iterator = header.program_header_iterator(kernel_file);
        //try vmm.init(&iterator, image_size, min_vaddr);
        //vmm.pagemap.load();

        var stack = try uefi.pool_allocator.alloc(u8, 65536);

        try kernel_file.close();
        while (utils.boot_services.exitBootServices(uefi.handle, memmap.memmap.key) == .InvalidParameter)
            try memmap.memmap.init();

        // zig fmt: off
        // zig fmt please kys i just want to make my asm all in one line
        asm volatile ("mov %[stack], %%rsp" :: [stack] "q" (@intFromPtr(stack.ptr) + 65536) : "memory");
        // zig fmt: on
        @as(*const fn () callconv(.SysV) void, @ptrFromInt(header.entry))();
        unreachable;
    } else {
        try kernel_file.close();
        return error.IncompatibleElf;
    }
}
