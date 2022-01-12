const console = @import("./console.zig");
const stage1 = @import("../stage1.zig");
const uefi = @import("std").os.uefi;

pub var graphics_output_protocol: ?*uefi.protocols.GraphicsOutputProtocol = undefined;

pub fn initialize() void {
    if (stage1.boot_services.locateProtocol(
        &uefi.protocols.GraphicsOutputProtocol.guid,
        null,
        @ptrCast(*?*anyopaque, &graphics_output_protocol),
    ) == .Success) {
        _ = console.con_out.reset(false);
        // TODO:: search for compatible mode and set 800x600 if the display is unsupported
        //_ = graphics_output_protocol.?.setMode(2);
    } else {
        console.puts("[error] unable to configure graphics mode\n");
    }
}
