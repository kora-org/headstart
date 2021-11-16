const uefi = @import("std").os.uefi;
const fmt = @import("std").fmt;

pub var con_out: *uefi.protocols.SimpleTextOutputProtocol = undefined;

const ConsoleColors = enum(u8) {
    black = con_out.black,
    blue = con_out.blue,
    green = con_out.green,
    cyan = con_out.cyan,
    red = con_out.red,
    magenta = con_out.magenta,
    brown = con_out.brown,
    light_grey = con_out.lightgray,
    dark_grey = con_out.darkgray,
    light_blue = con_out.lightblue,
    light_green = con_out.lightgreen,
    light_cyan = con_out.lightcyan,
    light_red = con_out.lightred,
    light_magenta = con_out.lightmagenta,
    light_brown = con_out.yellow,
    white = con_out.white,
};

var total_row: usize = undefined;
var total_column: usize = undefined;

pub fn initialize() void {
    _ = con_out.reset(false);
    _ = con_out.queryMode(undefined, &total_column, &total_row);
}

pub fn setColor(fg: ConsoleColors, bg: ConsoleColors) void {
    if (fg != undefined)
        con_out.setAttribute(@enumToInt(fg));
    if (bg != undefined)
        con_out.setAttribute(@enumToInt(bg));
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
