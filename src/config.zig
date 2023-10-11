const std = @import("std");
const uefi = std.os.uefi;
const builtin = @import("builtin");
const build_options = @import("build_options");
const utils = @import("utils.zig");
const console = @import("console/flanterm.zig");
const keyboard = @import("keyboard.zig");
const filesystem = @import("filesystem.zig");

pub const Config = struct {
    resolution: ?[]const u8 = null,
    entries: []Entry,

    pub const Entry = struct {
        name: []const u8,
        kernel: []const u8,
        protocol: Protocol,
        cmdline: ?[]const u8 = null,
        modules: ?[]Module = null,
    };

    pub const Module = struct {
        name: []const u8,
        module: []const u8,
    };

    pub const Protocol = enum {
        ydin,
        handover,
        limine,
        linux,
        chainload,
    };
};

pub fn showMenu(config: Config) !void {
    console.disableCursor();
    console.clear();
    var selected: usize = 0;
    while (true) {
        console.setCursorPosition(0, 0);
        try console.print("\n", .{});
        try console.print("  \x1b[92mHeadstart\x1b[0m v{s}\n\n", .{build_options.version});
        for (config.entries, 0..) |entry, i| {
            if (selected == i) {
                try console.print("  \x1b[92m>\x1b[0m {s}\n", .{entry.name});
            } else {
                try console.print("    {s}\n", .{entry.name});
            }
        }
        if (try keyboard.getKey()) |key_event| {
            if (key_event.scan_code.key) |key| {
                switch (key) {
                    .Up => {
                        if (@as(isize, @bitCast(selected)) - 1 < 0)
                            selected = config.entries.len
                        else
                            selected -= 1;
                    },
                    .Down => {
                        if (selected > config.entries.len - 2)
                            selected = 0
                        else
                            selected += 1;
                    },
                    else => {},
                }
            }
            if (key_event.scan_code.char) |key| {
                if (key == '\n') {
                    console.clear();
                    console.enableCursor();
                    try loadKernel(config.entries[selected]);
                    break;
                }
            }
        }
    }
}

pub fn loadKernel(kernel: Config.Entry) !void {
    switch (kernel.protocol) {
        //.chainload => {
        //    var kernel_file = try filesystem.open(kernel.kernel);
        //    var buffer = try kernel_file.reader().readAllAlloc(uefi.pool_allocator, @intCast(try kernel_file.getSize()));
        //    var device_path = try uefi.pool_allocator.alloc(
        //        uefi.protocols.DevicePath,
        //        @sizeOf(uefi.protocols.HardwareDevicePath.MemoryMappedDevicePath) + @sizeOf(uefi.protocols.EndDevicePath.EndEntireDevicePath),
        //    );
        //    device_path[0] = .{ .Hardware = .{ .MemoryMapped = &.{
        //        .type = .Hardware,
        //        .subtype = .MemoryMapped,
        //        .length = @sizeOf(uefi.protocols.HardwareDevicePath.MemoryMappedDevicePath),
        //        .memory_type = @intFromEnum(uefi.tables.MemoryType.LoaderData),
        //        .start_address = @intFromPtr(buffer.ptr),
        //        .end_address = buffer.len,
        //    } } };
        //    device_path[1] = .{ .End = .{ .EndEntire = &.{
        //        .type = .End,
        //        .subtype = .EndEntire,
        //        .length = @sizeOf(uefi.protocols.EndDevicePath.EndEntireDevicePath),
        //    } } };
        //
        //    var _handle: ?uefi.Handle = null;
        //    try utils.boot_services.loadImage(false, uefi.handle, @ptrCast(device_path.ptr), null, try kernel_file.getSize(), &_handle).err();
        //    try kernel_file.close();
        //
        //    if (_handle) |handle| {
        //        var exit_data_size: usize = 0;
        //        var exit_data: *anyopaque = undefined;
        //        var status = utils.boot_services.startImage(handle, &exit_data_size, @ptrCast(&exit_data));
        //        try utils.boot_services.exit(handle, status, exit_data_size, @constCast(exit_data)).err();
        //    }
        //},
        else => {
            var kernel_file = try filesystem.open(kernel.kernel);
            var buffer = try kernel_file.reader().readAllAlloc(uefi.pool_allocator, @intCast(try kernel_file.getSize()));
            try kernel_file.seekableStream().seekTo(0);
            var header = try std.elf.Header.read(kernel_file);
            if (header.machine.toTargetCpuArch() == builtin.cpu.arch) {
                var iterator = header.program_header_iterator(kernel_file);
                while (try iterator.next()) |phdr| {
                    if (phdr.p_type == std.elf.PT_LOAD) {
                        @memcpy(@as([*]u8, @ptrFromInt(phdr.p_paddr))[0..phdr.p_filesz], @as([*]u8, @ptrCast(buffer))[phdr.p_offset .. phdr.p_offset + phdr.p_filesz]);
                        if (phdr.p_memsz > phdr.p_filesz)
                            @memset(@as([*]u8, @ptrFromInt(phdr.p_paddr))[phdr.p_filesz..phdr.p_memsz], 0);
                    }
                }
                const HeadstartHeader = extern struct { print: *const fn ([*c]const u8) callconv(.SysV) void };
                const headstart_header = HeadstartHeader{ .print = &example_print };
                const entry = @as(*const fn (*const HeadstartHeader) callconv(.SysV) void, @ptrFromInt(header.entry));
                entry(&headstart_header);
                utils.halt();
            } else {
                return error.IncompatibleElf;
            }
            try kernel_file.close();
        },
    }
}

fn example_print(string: [*c]const u8) callconv(.SysV) void {
    console.print("{s}", .{std.mem.span(string)}) catch unreachable;
}
