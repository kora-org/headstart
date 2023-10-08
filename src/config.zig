pub const Config = struct {
    resolution: ?[]const u8,
    entries: []Entry,

    pub const Entry = struct {
        name: []const u8,
        kernel: []const u8,
        protocol: []const u8,
        cmdline: ?[]const u8 = null,
        modules: ?[]Module = null,
    };

    pub const Module = struct {
        name: []const u8,
        module: []const u8,
    };
};
