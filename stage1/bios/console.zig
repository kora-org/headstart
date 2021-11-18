const fmt = @import("std").fmt;

const VGA_WIDTH: usize = 80;
const VGA_HEIGHT: usize = 25;
const ConsoleColors = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    light_brown = 14,
    white = 15,
};

var row: usize = 0;
var column: usize = 0;
var color = vgaEntryColor(ConsoleColors.light_grey, ConsoleColors.black);
var buffer = @intToPtr([*]volatile u16, 0xB8000);

fn vgaEntryColor(fg: ConsoleColors, bg: ConsoleColors) u8 {
    return @enumToInt(fg) | (@enumToInt(bg) << 4);
}
 
fn vgaEntry(uc: u8, new_color: u8) u16 {
    var c: u16 = new_color;
    return uc | (c << 8);
}

pub fn initialize() void {
    var y: usize = 0;
    while (y < VGA_HEIGHT) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            putCharAt(' ', color, x, y);
        }
    }
}

pub fn setColor(fg: ConsoleColors, bg: ConsoleColors) void {
    color = vgaEntryColor(fg, bg);
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
