const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;

const ConsoleColors = enum(u4) {
    Black = con_out.black,
    Blue = con_out.blue,
    Green = con_out.green,
    Cyan = con_out.cyan,
    Red = con_out.red,
    Magenta = con_out.magenta,
    Brown = con_out.brown,
    LightGray = con_out.lightgray,
    DarkGray = con_out.darkgray,
    LightBlue = con_out.lightblue,
    LightGreen = con_out.lightgreen,
    LightCyan = con_out.lightcyan,
    LightRed = con_out.lightred,
    LightMagenta = con_out.lightmagenta,
    LightBrown = con_out.yellow,
    White = con_out.white
};

var total_row: usize = undefined;
var total_column: usize = undefined;

pub fn initialize() void {
    _ = con_out.reset(false);
    _ = con_out.queryMode(undefined, &total_column, &total_row);
    clear();
}

pub fn setColor(fg: ConsoleColors, bg: ConsoleColors) void {
    if (fg != undefined)
        con_out.setAttribute(@enumToInt(fg));
    if (bg != undefined)
        con_out.setAttribute(@enumToInt(bg));
}

pub fn clear() void {
    _ = con_out.clearScreen();
}

pub fn putCharAt(c: u8, x_: usize, y_: usize) void {
    var backup_x = @intCast(usize, con_out.mode.cursor_row);
    var backup_y = @intCast(usize, con_out.mode.cursor_column);

    var x = x_;
    var y = y_;

    if (&x_ == undefined)
        x = backup_x;
    if (&y_ == undefined)
        y = backup_y;

    _ = con_out.setCursorPosition(y, x);
    putChar(c);
    _ = con_out.setCursorPosition(backup_y, backup_x);
}

pub fn putChar(c: u8) void {
    const c_ = [2]u16{ c, 0 }; // work around https://github.com/ziglang/zig/issues/4372
    if (c == '\n') {
        _ = con_out.outputString(&[_:0]u16{ '\r', '\n' });
    } else {
        _ = con_out.outputString(@ptrCast(*const [1:0]u16, &c_));
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
