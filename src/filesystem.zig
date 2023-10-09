const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("utils.zig");

pub const File = struct {
    pub const ReadError = anyerror;
    pub const Reader = std.io.Reader(*File, ReadError, read);
    pub const SeekableStream = std.io.SeekableStream(*File, anyerror, anyerror, seekTo, seekBy, getPos, getSize);

    position: u64,
    file_protocol: *uefi.protocols.FileProtocol,

    pub fn reader(self: *const File) Reader {
        return .{ .context = @constCast(self) };
    }

    pub fn seekableStream(self: *const File) SeekableStream {
        return .{ .context = @constCast(self) };
    }

    fn read(self: *File, dest: []u8) ReadError!usize {
        if (try self.getSize() <= self.position) return 0;
        try self.file_protocol.seekableStream().seekTo(self.position);
        var len = try self.file_protocol.reader().read(dest);
        self.position += len;
        return len;
    }

    pub fn close(self: *File) !void {
        try self.file_protocol.close().err();
    }

    pub fn seekTo(self: *File, pos: u64) !void {
        self.position = pos;
    }

    pub fn seekBy(self: *File, pos: i64) !void {
        self.position += pos;
    }

    pub fn getPos(self: *File) !u64 {
        return self.position;
    }

    pub fn getSize(self: *File) !u64 {
        // preserve the old file position
        var pos: u64 = undefined;
        var end_pos: u64 = undefined;
        try self.file_protocol.getPosition(&pos).err();
        // seek to end of file to get position = file size
        try self.file_protocol.setPosition(uefi.protocols.FileProtocol.efi_file_position_end_of_file).err();
        try self.file_protocol.getPosition(&end_pos).err();
        // restore the old position
        try self.file_protocol.setPosition(pos).err();
        // return the file size = position
        return end_pos;
    }
};

var root_dir: *uefi.protocols.FileProtocol = undefined;

pub fn init() !void {
    var fs_protocol = try utils.loadProtocol(uefi.protocols.SimpleFileSystemProtocol);
    try fs_protocol.openVolume(&root_dir).err();
}

pub fn open(path: []const u8) !File {
    var file: *uefi.protocols.FileProtocol = undefined;
    var buffer = try uefi.pool_allocator.alloc(u16, path.len + 1);
    buffer[path.len] = 0;
    for (path, 0..) |c, i| {
        buffer[i] = c;
        if (c == '/') buffer[i] = '\\';
    }

    try root_dir.open(@constCast(&file), @ptrCast(buffer.ptr), uefi.protocols.FileProtocol.efi_file_mode_read, 0).err();
    uefi.pool_allocator.free(buffer);

    return .{
        .position = 0,
        .file_protocol = file,
    };
}
