const std = @import("std");
const utf16 = std.unicode.utf8ToUtf16LeStringLiteral;
const uefi = std.os.uefi;

pub const Color = enum(u8) {
    Black = uefi.protocols.SimpleTextOutputProtocol.black,
    Blue = uefi.protocols.SimpleTextOutputProtocol.blue,
    Green = uefi.protocols.SimpleTextOutputProtocol.green,
    Cyan = uefi.protocols.SimpleTextOutputProtocol.cyan,
    Red = uefi.protocols.SimpleTextOutputProtocol.red,
    Magenta = uefi.protocols.SimpleTextOutputProtocol.magenta,
    Brown = uefi.protocols.SimpleTextOutputProtocol.brown,
    LightGray = uefi.protocols.SimpleTextOutputProtocol.lightgray,
    DarkGray = uefi.protocols.SimpleTextOutputProtocol.darkgray,
    LightBlue = uefi.protocols.SimpleTextOutputProtocol.lightblue,
    LightGreen = uefi.protocols.SimpleTextOutputProtocol.lightgreen,
    LightCyan = uefi.protocols.SimpleTextOutputProtocol.lightcyan,
    LightRed = uefi.protocols.SimpleTextOutputProtocol.lightred,
    LightMagenta = uefi.protocols.SimpleTextOutputProtocol.lightmagenta,
    LightBrown = uefi.protocols.SimpleTextOutputProtocol.yellow,
    White = uefi.protocols.SimpleTextOutputProtocol.white,
};

pub var console_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;
pub var row: usize = undefined;
pub var column: usize = undefined;

pub fn init(con_out: *uefi.protocols.SimpleTextOutputProtocol) void {
    console_out = con_out;
    _ = console_out.reset(true);
}

pub fn enableCursor() void {
    _ = console_out.enableCursor(true);
}

pub fn disableCursor() void {
    _ = console_out.enableCursor(false);
}

pub fn setCursorPosition(x: usize, y: usize) void {
    _ = console_out.setCursorPosition(y, x);
}

pub fn getCursorPosition() u16 {
    return column + row;
}

pub fn setColor(fg: ?Color, bg: ?Color) void {
    if (fg) |fg_| {
        _ = console_out.setAttribute(@intFromEnum(fg_));
    }

    if (bg) |bg_| {
        _ = console_out.setAttribute(@intFromEnum(bg_));
    }
}

pub fn clear() void {
    _ = console_out.clearScreen();
}

pub fn putCharAt(char: u8, x_: usize, y_: usize) void {
    var backup_x = @as(usize, @intCast(console_out.mode.cursor_row));
    var backup_y = @as(usize, @intCast(console_out.mode.cursor_column));

    var x = x_;
    var y = y_;

    if (&x_ == undefined)
        x = backup_x;

    if (&y_ == undefined)
        y = backup_y;

    _ = console_out.setCursorPosition(y, x);
    putChar(char);
    _ = console_out.setCursorPosition(backup_y, backup_x);
}

pub fn putChar(char: u8) void {
    const c = [2]u16{ char, 0 };
    if (char == '\n') {
        _ = console_out.outputString(&[_:0]u16{ '\r', '\n' });
    } else {
        _ = console_out.outputString(@as(*const [1:0]u16, @ptrCast(&c)));
    }
}

pub fn write(string: []const u8) void {
    for (string) |c| putChar(c);
}

pub const writer = std.io.Writer(void, error{}, callback){
    .context = {},
};

fn callback(_: void, string: []const u8) error{}!usize {
    write(string);
    return string.len;
}

pub fn print(comptime format: []const u8, args: anytype) !void {
    try writer.print(format, args);
}
