const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;
const Writer = @import("std").io.Writer;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;

pub const ConsoleColors = enum(u8) {
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

var row: usize = undefined;
var column: usize = undefined;

pub fn initialize() void {
    _ = con_out.reset(false);
    _ = con_out.queryMode(undefined, &column, &row);
    clear();
}

pub fn enableCursor() void {
    _ = con_out.enableCursor(true);
}

pub fn disableCursor() void {
    _ = con_out.enableCursor(false);
}

pub fn setColor(comptime fg: ?ConsoleColors, comptime bg: ?ConsoleColors) void {
    if (fg) |fg_| {
        _ = con_out.setAttribute(@enumToInt(fg_));
    }

    if (bg) |bg_| {
        _ = con_out.setAttribute(@enumToInt(bg_));
    }
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

pub const writer = Writer(void, error{}, callback){ .context = {} };

fn callback(_: void, string: []const u8) error{}!usize {
    puts(string);
    return string.len;
}

pub fn printf(comptime format: []const u8, args: anytype) void {
    fmt.format(writer, format, args) catch unreachable;
}
