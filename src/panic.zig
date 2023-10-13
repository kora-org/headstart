const std = @import("std");
const utils = @import("utils.zig");

// TODO: try find out how to get debug info out of codeview debug infos
pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    std.log.err("Panic: {s}", .{message});

    // FIXME:
    // /usr/lib/zig/std/os.zig:103:23: error: root struct of file 'os.uefi' has no member named 'MSF'
    // pub const MSF = system.MSF;
    //                 ~~~~~~^~~~
    _ = return_address;
    //var stack_iterator = std.debug.StackIterator.init(return_address orelse @returnAddress(), @frameAddress());
    //std.log.err("Stack trace:", .{});

    //while (stack_iterator.next()) |address| {
    //    if (address != 0)
    //        std.log.err("  - 0x{x}", .{address});
    //}

    std.log.err("System halted.", .{});
    utils.halt();
}
