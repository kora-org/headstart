const io = @import("../../lib/io.zig");
const fmt = @import("std").fmt;
const mem = @import("std").mem;

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

pub const ConsoleColors = enum(u4) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGray = 7,
    DarkGray = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    LightBrown = 14,
    White = 15,
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(ConsoleColors.LightGray, ConsoleColors.Black);
var buffer = @intToPtr([*]volatile u16, 0xB8000);

pub fn vgaEntryColor(fg: ?ConsoleColors, bg: ?ConsoleColors) u8 {
    var fg_: ConsoleColors = ConsoleColors.LightGray;
    var bg_: ConsoleColors = ConsoleColors.Black;

    if (fg) |fg__| {
        fg_ = fg__;
    }

    if (bg) |bg__| {
        bg_ = bg__;
    }

    return @as(u8, @enumToInt(fg_)) | (@as(u8, @enumToInt(bg_)) << 4);
}

fn vgaEntry(uc: u8, new_color: u8) u16 {
    return uc | (@as(u16, new_color) << 8);
}

pub fn initialize() void {
    clear();
}

pub fn enableCursor() void {
    io.outb(0x3D4, 0x0A);
    io.outb(0x3D5, (io.inb(0x3D5) & 0xC0) | 15);

    io.outb(0x3D4, 0x0B);
    io.outb(0x3D5, (io.inb(0x3D5) & 0xE0) | 13);
}

pub fn disableCursor() void {
    io.outb(0x3D4, 0x0A);
    io.outb(0x3D5, 0x20);
}

pub fn setCursorPosition(x: u16, y: u16) void {
    const pos = y * VGA_WIDTH + x;

    io.outb(0x3D4, 0x0F);
    io.outb(0x3D5, pos & 0xFF);
    io.outb(0x3D4, 0x0E);
    io.outb(0x3D5, (pos >> 8) & 0xFF);
}

pub fn getCursorPosition() u16 {
    var pos: u16 = 0;
    io.outb(0x3D4, 0x0F);
    pos |= io.inb(0x3D5);
    io.outb(0x3D4, 0x0E);
    pos |= io.inb(0x3D5) << 8;
    return pos;
}

pub fn setColor(fg: ?ConsoleColors, bg: ?ConsoleColors) void {
    color = vgaEntryColor(fg, bg);
}

pub fn clear() void {
    mem.set(u16, buffer[0..VGA_SIZE], vgaEntry(' ', color));
}

fn scroll() void {
    var x: usize = 0;
    var y: usize = 0;

    while (y < VGA_HEIGHT - 1) : (y += 1) {
        while (x < VGA_WIDTH) : (x += 1) {
            buffer[(y * VGA_WIDTH) + x] = buffer[((y + 1) * VGA_WIDTH) + x];
        }
    }

    while (x < VGA_WIDTH) : (x += 1) {
        buffer[(y * VGA_WIDTH) + x] = vgaEntry(' ', color);
    }

    column = 0;
    row = VGA_HEIGHT - 1;
}

pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
    const index: usize = y * VGA_WIDTH + x;
    buffer[index] = vgaEntry(c, new_color);
}

pub fn putChar(c: u8) void {
    switch (c) {
        '\r' => column = 0,
        '\n' => {
            column = 0;
            row += 1;
        },
        '\t' => column += 8,
        else => putCharAt(c, color, column, row),
    }

    if (c != '\n') {
        column += 1;
        if (column == VGA_WIDTH) {
            column = 0;
            row += 1;
            if (row == VGA_HEIGHT) {
                scroll();
            }
        }
    } else {
        if (row == VGA_HEIGHT) {
            scroll();
        }
    }
}

pub fn puts(data: []const u8) void {
    for (data) |c|
        putChar(c);
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    var buf: [100]u8 = undefined;
    puts(fmt.bufPrint(&buf, format, args) catch unreachable);
}
