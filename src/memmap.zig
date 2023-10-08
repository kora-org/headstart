const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("utils.zig");

pub const MAX_ENTRIES = 1024;
pub const MemoryMap = struct {
    entries: [MAX_ENTRIES]Entry,
    count: usize,

    const errors = error{
        MinifyLogicFailure,
        OutOfEntries,
        OutOfMemory,
    };

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
        /// Memory that can be reclaimed and used by the kernel after parsing ACPI tables.
        AcpiReclaimable,
        /// Memory that are reserved for use by the firmware.
        AcpiNvs,
        /// Memory that are corrupted or unusable.
        Unusable,
    };

    /// Removes entries with length 0
    pub fn removeEmpty(self: *MemoryMap) void {
        for (0..self.count) |i| {
            if (self.entries[i].length != 0) continue;

            for (i..self.count - 1) |j|
                self.entries[j] = self.entries[j + 1];

            self.count -= 1;
        }
    }

    pub fn sort(self: *MemoryMap) void {
        std.sort.insertion(Entry, self.entries[0..self.count], {}, struct {
            pub fn lessThan(_: @TypeOf({}), lhs: Entry, rhs: Entry) bool {
                return lhs.base < rhs.base;
            }
        }.lessThan);
    }

    /// Combines memory map entries that touch or overlap of the same type, removes invalid entries, and sorts the map
    pub fn minify(self: *MemoryMap) !void {
        self.removeEmpty();
        var i: u32 = 0;
        // Because the memory map is not necessarily in order, we do two loops
        // One that goes through every entry and holds it, and one that goes
        // through every entry and checks for collisions
        while (i < self.count) : (i += 1) {
            if (i > MAX_ENTRIES) return error.MinifyLogicFailure;
            const outer = &self.entries[i];
            if (outer.length == 0) continue;
            var j: u32 = 0;
            while (j < self.count) : (j += 1) {
                if (j > MAX_ENTRIES) return error.MinifyLogicFailure;
                if (j == i) continue;
                const inner = &self.entries[j];
                if (inner.length == 0) continue;
                // If they don't touch, continue
                if (outer.base > inner.base or inner.base > outer.base + outer.length) continue;
                if (@intFromEnum(outer.type) < @intFromEnum(inner.type)) {
                    if (outer.base + outer.length > inner.base + inner.length) {
                        self.entries[self.count] = .{
                            .base = inner.base + inner.length,
                            .length = (outer.base + outer.length) - (inner.base + inner.length),
                            .type = outer.type,
                        };
                        self.count += 1;
                    }
                    outer.length = inner.base - outer.base;
                } else if (@intFromEnum(outer.type) == @intFromEnum(inner.type)) {
                    const newLength = @max(inner.base + inner.length - outer.base, outer.length);
                    outer.length = newLength;
                    inner.length = 0;
                    self.removeEmpty();
                    j -= 1;
                }
            }
        }
        self.removeEmpty();
        self.sort();
    }

    pub fn usableMax(self: *MemoryMap) u64 {
        var max: u64 = 0;
        for (0..self.count) |c| {
            if (self.entries[c].type == .usable) {
                max = @max(max, self.entries[c].base + self.entries[c].length);
            }
        }
        return max;
    }

    /// Inserts a new entry and sanitizes the memory map, so the entry may not exactly match what is put in.
    pub fn addEntry(self: *MemoryMap, entry: Entry) !void {
        if (self.count >= MAX_ENTRIES) return error.OutOfEntries;
        self.entries[self.count] = entry;
        self.count += 1;
        try self.minify();
    }

    pub fn reserveSpace(self: *MemoryMap, size: u64) !Entry {
        var entry: ?Entry = null;
        for (0..self.count) |e| {
            if (self.entries[e].type == .Usable and self.entries[e].length >= size and self.entries[e].base >= 0x100000) {
                entry = self.entries[e];
                break;
            }
        }
        if (entry) |e| {
            var to_insert: Entry = .{
                .base = e.base,
                .length = size,
                .type = .Bootloader,
            };
            try self.addEntry(to_insert);
            return to_insert;
        }
        return error.OutOfMemory;
    }
};

pub var memmap: MemoryMap = undefined;
pub var map_key: usize = 0; // Needed to exit boot services

pub fn init() !void {
    var entries: []align(8) u8 = undefined;
    var size: usize = 0;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;
    while (utils.boot_services.getMemoryMap(&size, @as([*]uefi.tables.MemoryDescriptor, @ptrCast(@alignCast(entries.ptr))), &map_key, &descriptor_size, &descriptor_version) == .BufferTooSmall) {
        try utils.boot_services.allocatePool(.BootServicesData, size, @ptrCast(&entries)).err();
    }
    const entry_count = size / descriptor_size;
    if (entry_count > MAX_ENTRIES) @panic("Too many memory map entries!");
    var ptr = entries.ptr;
    for (0..entry_count) |i| {
        ptr = @alignCast(entries.ptr + descriptor_size * i);
        const entry = @as(*uefi.tables.MemoryDescriptor, @ptrCast(@alignCast(ptr)));
        memmap.entries[i] = .{
            .base = entry.physical_start,
            .length = entry.number_of_pages * std.mem.page_size,
            .type = switch (entry.type) {
                .ReservedMemoryType, .MemoryMappedIO, .MemoryMappedIOPortSpace, .PalCode => .Reserved,
                .LoaderCode, .LoaderData, .BootServicesCode, .BootServicesData => .Bootloader,
                .RuntimeServicesCode, .RuntimeServicesData => .Kernel,
                .ConventionalMemory, .PersistentMemory => .Usable,
                .UnusableMemory => .Unusable,
                .ACPIReclaimMemory => .AcpiReclaimable,
                .ACPIMemoryNVS => .AcpiNvs,
                else => .Unusable,
            },
        };
    }
    memmap.count = entry_count;
    try utils.boot_services.freePool(@ptrCast(@alignCast(entries.ptr))).err();
}
