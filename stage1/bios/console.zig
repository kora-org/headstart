const fmt = @import("std").fmt;
const mem = @import("std").mem;

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_SIZE = VGA_WIDTH * VGA_HEIGHT;

const ConsoleColors = enum(u8) {
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
    White = 15
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(ConsoleColors.LightGray, ConsoleColors.Black);
var buffer = @intToPtr([*]volatile u16, 0xB8000);

fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
    return @enumToInt(fg) | (@enumToInt(bg) << 4);
}
 
fn vgaEntry(uc: u8, new_color: u8) u16 {
    var c: u16 = new_color;
    return uc | (c << 8);
}

pub fn initialize() void {
    clear();
}

pub fn setColor(fg: ConsoleColors, bg: ConsoleColors) void {
    color = vgaEntryColor(fg, bg);
}

pub fn clear() void {
    mem.set(u16, buffer[0..VGA_SIZE], vgaEntry(' ', color));
}

pub fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) void {
    const index: usize = y * VGA_WIDTH + x;
    buffer[index] = vgaEntry(c, new_color);
}

pub fn putChar(c: u8) void {
    putCharAt(c, color, column, row);
    if (column == VGA_WIDTH) {
        column = 0;
        if (row == VGA_HEIGHT)
            row = 0;
    }
}

pub fn puts(data: []const u8) void {
    for (data) |i|
        putChar(data[i]);
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    var buf: [100]u8 = undefined;
    puts(fmt.bufPrint(&buf, format, args) catch unreachable);
}
