const std = @import("std");
const uefi = std.os.uefi;
const c = @cImport({
    @cInclude("flanterm/flanterm.h");
    @cInclude("flanterm/backends/fb.h");
});

pub var console: *c.flanterm_context = undefined;

pub fn init(gop: *uefi.protocols.GraphicsOutputProtocol) void {
    console = c.flanterm_fb_simple_init(
        gop.mode.frame_buffer_base,
        gop.mode.info.horizontal_resolution,
        gop.mode.info.vertical_resolution,
        gop.mode.info.horizontal_resolution * 4,
    );
}

pub fn enableCursor() void {
    console.cursor_enabled = true;
}

pub fn disableCursor() void {
    console.cursor_enabled = false;
}

pub fn setCursorPosition(x: usize, y: usize) void {
    console.set_cursor_pos(x, y);
}

pub fn getCursorPosition() usize {
    var x: usize = 0;
    var y: usize = 0;
    console.get_cursor_pos(&x, &y);
    return x + y;
}

pub fn clear() void {
    console.clear();
}

pub fn putCharAt(char: u8, x_: usize, y_: usize) void {
    var backup_x: usize = 0;
    var backup_y: usize = 0;
    console.get_cursor_pos(&backup_x, &backup_y);

    var x = x_;
    var y = y_;

    if (&x_ == undefined)
        x = backup_x;

    if (&y_ == undefined)
        y = backup_y;

    console.set_cursor_pos(x, y);
    putChar(char);
    console.set_cursor_pos(backup_x, backup_y);
}

pub fn putChar(char: u8) void {
    console.raw_putchar(char);
}

pub fn write(string: []const u8) void {
    c.flanterm_write(console, string.ptr, string.len);
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
