const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("utils.zig");
const memmap = @import("memmap.zig");

pub const CacheMode = enum(u4) {
    Uncached,
    WriteCombining,
    WriteProtect,
    WriteBack,
};

pub const PageFlags = struct {
    read: bool = false,
    write: bool = false,
    exec: bool = false,
    user: bool = false,
    cache_type: CacheMode = .WriteBack,
};

pub var pagemap = Pagemap{};

pub fn init(phdrs: anytype, physical_base: u64, virtual_base: u64) !void {
    try utils.boot_services.allocatePages(.AllocateAnyPages, .LoaderData, 1, @ptrCast(&pagemap)).err();

    var page_flags = PageFlags{
        .read = true,
        .write = true,
        .exec = true,
    };

    while (try phdrs.next()) |phdr| {
        if (phdr.p_type == std.elf.PT_LOAD and phdr.p_vaddr > 0xffffffff80000000) {
            var virt: u64 = phdr.p_vaddr & ~(phdr.p_align - 1);
            var phys: u64 = 0;

            if (virt & (1 << 63) == 1)
                phys = physical_base + (virt - virtual_base)
            else
                @panic("Virtual address of a PHDR is in the lower half");

            var i: usize = 0;
            while (i < std.mem.alignForward(u64, (phdr.p_vaddr + phdr.p_memsz) - virt, phdr.p_align)) : (i += 0x1000)
                try pagemap.mapPage(.{
                    .read = (phdr.p_flags & 0b111) & std.elf.PF_R == 1,
                    .write = (phdr.p_flags & 0b111) & std.elf.PF_W == 1,
                    .exec = (phdr.p_flags & 0b111) & std.elf.PF_X == 1,
                }, virt + i, phys + i, false);
        }
    }

    var i: usize = 0;
    while (i < 0x200000) : (i += 0x1000) {
        if (i == 0)
            try pagemap.mapPage(page_flags, i, i, false);
        try pagemap.mapPage(page_flags, pagemap.offset + i, i, false);
    }

    i = 0x2000000;
    while (i < 0x40000000) : (i += 0x2000000) {
        try pagemap.mapPage(page_flags, i, i, false);
        try pagemap.mapPage(page_flags, pagemap.offset + i, i, false);
    }

    i = 0x40000000;
    while (i < 0x100000000) : (i += 0x40000000) {
        try pagemap.mapPage(page_flags, i, i, true);
        try pagemap.mapPage(page_flags, pagemap.offset + i, i, true);
    }

    for (memmap.memmap.entries) |ent| {
        if (ent.base + ent.length < 0x100000000) {
            continue;
        }

        var base: usize = std.mem.alignBackward(u64, ent.base, 0x40000000);

        i = 0;
        while (i < std.mem.alignForward(u64, ent.length, 0x40000000)) : (i += 0x40000000) {
            try pagemap.mapPage(page_flags, base + i, base + i, true);
            try pagemap.mapPage(page_flags, pagemap.offset + base + i, base + i, true);
        }
    }
}

pub const Pagemap = struct {
    const Self = @This();

    root: u64 = undefined,
    offset: u64 = 0xffff800000000000,

    pub fn load(self: *Self) void {
        asm volatile ("mov %[root], %%cr3"
            :
            : [root] "r" (self.root),
            : "memory"
        );
    }

    pub fn save(self: *Self) void {
        self.root = asm volatile ("mov %%cr3, %[old_cr3]"
            : [old_cr3] "=r" (-> u64),
            :
            : "memory"
        );
    }

    pub fn mapPage(self: *Self, flags: PageFlags, virt: u64, phys: u64, huge: bool) !void {
        var root: ?[*]u64 = @as([*]u64, @ptrFromInt(self.root + self.offset));

        var indices: [4]u64 = [_]u64{
            genIndex(virt, 39), genIndex(virt, 30),
            genIndex(virt, 21), genIndex(virt, 12),
        };

        root = try getNextLevel(root.?, indices[0], true);
        if (root == null) return;

        root = try getNextLevel(root.?, indices[1], true);
        if (root == null) return;

        if (huge)
            root.?[indices[2]] = createPte(flags, phys, true)
        else {
            root = try getNextLevel(root.?, indices[2], true);
            root.?[indices[3]] = createPte(flags, phys, false);
        }
    }

    pub fn unmapPage(self: *Self, virt: u64) void {
        var root: ?[*]u64 = @as([*]u64, @ptrFromInt(self.root + self.offset));

        var indices: [4]u64 = [_]u64{
            genIndex(virt, 39), genIndex(virt, 30),
            genIndex(virt, 21), genIndex(virt, 12),
        };

        root = getNextLevel(root.?, indices[0], false);
        if (root == null) return;

        root = getNextLevel(root.?, indices[1], false);
        if (root == null) return;

        if ((root.?[indices[2]] & (1 << 7)) != 0)
            root.?[indices[2]] &= ~@as(u64, 1)
        else if (getNextLevel(root.?, indices[2], false)) |final_root|
            final_root[indices[3]] &= ~@as(u64, 1);

        invalidatePage(virt);
    }
};

inline fn genIndex(virt: u64, comptime shift: usize) u64 {
    return ((virt & (0x1ff << shift)) >> shift);
}

fn getNextLevel(level: [*]u64, index: usize, create: bool) !?[*]u64 {
    if ((level[index] & 1) == 0) {
        if (!create) return null;

        var _table_ptr: ?[*]u8 = undefined;
        try utils.boot_services.allocatePages(.AllocateAnyPages, .LoaderData, 1, @ptrCast(&_table_ptr)).err();
        if (_table_ptr) |table_ptr| {
            level[index] = @intFromPtr(table_ptr);
            level[index] |= 0b111;
        } else return null;
    }

    return @as([*]u64, @ptrFromInt((level[index] & ~@as(u64, 0x1ff)) + pagemap.offset));
}

fn createPte(flags: PageFlags, phys_ptr: u64, huge: bool) u64 {
    var result: u64 = 1;
    var pat_bit: u64 = if (huge) (1 << 12) else (1 << 7);

    if (flags.write) result |= (1 << 1);
    if (!flags.exec) result |= (1 << 63);
    if (flags.user) result |= (1 << 2);
    if (huge) result |= (1 << 7);

    switch (flags.cache_type) {
        .Uncached => {
            result |= (1 << 4) | (1 << 3);
            result &= ~pat_bit;
        },
        .WriteCombining => result |= pat_bit | (1 << 4) | (1 << 3),
        .WriteProtect => {
            result |= pat_bit | (1 << 4);
            result &= ~@as(u64, 1 << 3);
        },
        else => {},
    }

    result |= phys_ptr;
    return result;
}

pub inline fn invalidatePage(addr: u64) void {
    asm volatile ("invlpg (%[virt])"
        :
        : [virt] "r" (addr),
        : "memory"
    );
}
