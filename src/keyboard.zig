const uefi = @import("std").os.uefi;
const utils = @import("utils.zig");

var in_ext: ?*uefi.protocols.SimpleTextInputExProtocol = null;

pub const ScanCode = struct {
    char: ?u8 = null,
    key: ?Key = null,
};

pub const Key = enum {
    Invalid,
    Up,
    Down,
    Left,
    Right,
    CtrlL,
    AltL,
    ShiftL,
    CtrlR,
    AltR,
    ShiftR,
    Super,
    CapsLock,
    Enter,
    Backspace,
    Esc,
    NumLock,
    ScrollLock,
    PrintScreen,
    Pause,
    End,
    Home,
    Insert,
    Delete,
    PageUp,
    PageDown,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
};

pub const KeyEvent = struct {
    scan_code: ScanCode = .{},
    event_type: EventType = .Pressed,
    modifiers: Modifiers = .{},

    pub const EventType = enum { Pressed, Released };
    pub const Modifiers = struct {
        ctrl: bool = false,
        alt: bool = false,
        shift: bool = false,
        super: bool = false,
    };
};

pub fn init() !void {
    in_ext = try utils.loadProtocol(uefi.protocols.SimpleTextInputExProtocol);
    try in_ext.?.reset(true).err();
}

pub fn getKey() !?KeyEvent {
    var key: uefi.protocols.KeyData = undefined;
    if (in_ext) |in| {
        try utils.waitForEvent(in.wait_for_key_ex);
        in.readKeyStrokeEx(&key).err() catch return null;
        return .{
            .scan_code = .{
                .key = switch (key.key.scan_code) {
                    1 => .Up,
                    2 => .Down,
                    3 => .Right,
                    4 => .Left,
                    5 => .Home,
                    6 => .End,
                    7 => .Insert,
                    8 => .Delete,
                    9 => .PageUp,
                    10 => .PageDown,
                    11 => .F1,
                    12 => .F2,
                    13 => .F3,
                    14 => .F4,
                    15 => .F5,
                    16 => .F6,
                    17 => .F7,
                    18 => .F8,
                    19 => .F9,
                    20 => .F10,
                    21 => .F11,
                    22 => .F12,
                    23 => .Esc,
                    else => blk: {
                        if (key.key_state.key_shift_state.left_control_pressed)
                            break :blk .CtrlL
                        else if (key.key_state.key_shift_state.right_control_pressed)
                            break :blk .CtrlR
                        else if (key.key_state.key_shift_state.left_alt_pressed)
                            break :blk .AltL
                        else if (key.key_state.key_shift_state.right_alt_pressed)
                            break :blk .AltR
                        else if (key.key_state.key_shift_state.left_shift_pressed)
                            break :blk .ShiftL
                        else if (key.key_state.key_shift_state.right_shift_pressed)
                            break :blk .ShiftR
                        else if (key.key_state.key_shift_state.left_logo_pressed or key.key_state.key_shift_state.right_logo_pressed)
                            break :blk .Super
                        else if (key.key_state.key_shift_state.sys_req_pressed)
                            break :blk .PrintScreen
                        else if (key.key_state.key_toggle_state.scroll_lock_active)
                            break :blk .ScrollLock
                        else if (key.key_state.key_toggle_state.num_lock_active)
                            break :blk .NumLock
                        else if (key.key_state.key_toggle_state.caps_lock_active)
                            break :blk .CapsLock
                        else
                            break :blk null;
                    },
                },
                .char = if (key.key.unicode_char == 0) null else switch (key.key.unicode_char) {
                    0x09 => '\t',
                    0x0a => '\n',
                    0x0d => '\n',
                    else => @intCast(key.key.unicode_char),
                },
            },
            .modifiers = .{
                .ctrl = key.key_state.key_shift_state.left_control_pressed or key.key_state.key_shift_state.right_control_pressed,
                .alt = key.key_state.key_shift_state.left_alt_pressed or key.key_state.key_shift_state.right_alt_pressed,
                .shift = key.key_state.key_shift_state.left_shift_pressed or key.key_state.key_shift_state.right_shift_pressed,
                .super = key.key_state.key_shift_state.left_logo_pressed or key.key_state.key_shift_state.right_logo_pressed,
            },
        };
    }
    return null;
}
