const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("../utils.zig");
const c = @cImport({
    @cInclude("flanterm/flanterm.h");
    @cInclude("flanterm/backends/fb.h");
});

pub var console: *c.flanterm_context = undefined;
pub var framebuffer: []u8 = undefined;

export fn _malloc(size: usize) callconv(.C) ?*anyopaque {
    const ret = uefi.pool_allocator.alloc(u8, size) catch unreachable;
    return @as(*anyopaque, @ptrCast(ret.ptr));
}

export fn _free(ptr: ?*anyopaque, _: usize) callconv(.C) void {
    _ = uefi.system_table.boot_services.?.freePool(@alignCast(@ptrCast(ptr.?)));
}

pub fn init() void {
    framebuffer = uefi.pool_allocator.alloc(u8, utils.gop.mode.info.horizontal_resolution * utils.gop.mode.info.vertical_resolution * 4) catch unreachable;
    console = c.flanterm_fb_init(
        &_malloc,
        &_free,
        @intFromPtr(framebuffer.ptr),
        utils.gop.mode.info.horizontal_resolution,
        utils.gop.mode.info.vertical_resolution,
        utils.gop.mode.info.horizontal_resolution * 4,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        0,
        0,
        1,
        1,
        1,
        0,
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

pub fn putChar(char: u8) !void {
    console.raw_putchar(char);
    try utils.blit(framebuffer);
}

pub fn write(string: []const u8) !void {
    c.flanterm_write(console, string.ptr, string.len);
    try utils.blit(framebuffer);
}

pub const writer = std.io.Writer(void, uefi.Status.EfiError, callback){
    .context = {},
};

fn callback(_: void, string: []const u8) !usize {
    try write(string);
    return string.len;
}

pub fn print(comptime format: []const u8, args: anytype) !void {
    try writer.print(format, args);
}
