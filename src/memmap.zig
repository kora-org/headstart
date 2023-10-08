const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("utils.zig");

const MemoryMap = struct {
    memory_map: []align(8) u8,
    entries: []Entry,
    entry_count: usize,
    key: usize,
    desc_size: usize,
    desc_version: u32,

    const memory_map_size = 64 * 1024;

    pub const Entry = extern struct {
        base: u64,
        length: u64,
        type: Types,
    };

    pub const Types = enum(u64) {
        /// Always usable memory.
        Usable,
        /// Reserved for miscellaneous reasons.
        Reserved,
        /// Memory that are reserved for use by the bootloader.
        Bootloader,
        /// Memory that are reserved for the kernel by the bootloader.
        Kernel,
        /// Memory that can be reclaimed and used by the kernel after the bootloader exited boot services.
        EfiReclaimable,
        /// Memory that can be reclaimed and used by the kernel after parsing ACPI tables.
        AcpiReclaimable,
        /// Memory that are reserved for use by the firmware.
        AcpiNvs,
        /// Memory that are corrupted or unusable.
        Unusable,
    };

    const Iterator = struct {
        map: *const MemoryMap,
        curr_offset: usize = 0,

        fn next(self: *@This()) ?*uefi.tables.MemoryDescriptor {
            if (self.curr_offset + @offsetOf(uefi.tables.MemoryDescriptor, "attribute") >= self.map.memory_map.len)
                return null;

            const result = @as(*uefi.tables.MemoryDescriptor, @ptrCast(@alignCast(self.map.memory_map.ptr + self.curr_offset)));
            self.curr_offset += self.map.desc_size;
            return result;
        }
    };

    /// Clean up entries.
    fn sanitize(self: *MemoryMap) void {
        var count: usize = self.entry_count;
        for (0..count) |i| {
            if (self.entries[i].type != .Usable)
                continue;

            // Check if the entry overlaps other entries
            for (0..count) |j| {
                if (j == i) continue;

                var base: u64 = self.entries[i].base;
                var length: u64 = self.entries[i].length;
                var top: u64 = base + length;

                var res_base: u64 = self.entries[j].base;
                var res_length: u64 = self.entries[j].length;
                var res_top: u64 = res_base + res_length;

                if ((res_base >= base and res_base < top) and (res_top >= base and res_top < top)) {
                    // TODO actually handle splitting off usable chunks
                    @panic("A non-usable memory map entry is inside a usable section.");
                }

                if (res_base >= base and res_base < top) top = res_base;
                if (res_top >= base and res_top < top) base = res_top;

                self.entries[i].base = base;
                self.entries[i].length = top - base;
            }
        }

        // Remove 0 length usable entries and usable entries below 0x1000
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (self.entries[i].type != .Usable) continue;

            if (self.entries[i].base < 0x1000) {
                if (self.entries[i].base + self.entries[i].length <= 0x1000) {
                    // Remove i from memmap
                    self.entries[i] = self.entries[count - 1];
                    count -= 1;
                    i -= 1;
                }

                self.entries[i].length -= 0x1000 - self.entries[i].base;
                self.entries[i].base = 0x1000;
            }

            if (self.entries[i].length == 0) {
                // Remove i from memmap
                self.entries[i] = self.entries[count - 1];
                count -= 1;
                i -= 1;
            }
        }

        // Sort the entries
        std.sort.insertion(Entry, self.entries[0..count], {}, struct {
            pub fn lessThan(_: @TypeOf({}), lhs: Entry, rhs: Entry) bool {
                return lhs.base < rhs.base;
            }
        }.lessThan);

        self.entry_count = count;
    }

    pub fn init(self: *@This()) !void {
        self.memory_map.ptr = @ptrCast(@alignCast(try uefi.pool_allocator.alloc(u8, memory_map_size)));
        self.memory_map.len = memory_map_size;
        try uefi.system_table.boot_services.?.getMemoryMap(&self.memory_map.len, @ptrCast(@alignCast(self.memory_map.ptr)), &self.key, &self.desc_size, &self.desc_version).err();

        var iter = Iterator{ .map = self };
        var num_entries: usize = 0;
        var entries: [1024]Entry = undefined;

        while (iter.next()) |entry| : (num_entries += 1) {
            entries[num_entries] = .{
                .base = entry.physical_start,
                .length = entry.number_of_pages * std.mem.page_size,
                .type = switch (entry.type) {
                    .ReservedMemoryType, .MemoryMappedIO, .MemoryMappedIOPortSpace, .PalCode => .Reserved,
                    .LoaderCode, .LoaderData => .Bootloader,
                    .BootServicesCode, .BootServicesData => .EfiReclaimable,
                    .RuntimeServicesCode, .RuntimeServicesData => .Kernel,
                    .ConventionalMemory, .PersistentMemory => .Usable,
                    .UnusableMemory => .Unusable,
                    .ACPIReclaimMemory => .AcpiReclaimable,
                    .ACPIMemoryNVS => .AcpiNvs,
                    else => .Unusable,
                },
            };
        }

        self.entry_count = num_entries;
        self.entries = entries[0..self.entry_count];
        self.sanitize();
    }
};

pub var memmap: MemoryMap = undefined;
