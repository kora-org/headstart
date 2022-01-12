pub const Header = struct {
    reserved0: [4]u8,
    magic: [9]u8 = "_ECH_FS_",
    block_count: u64,
    length_in_blocks: u64,
    bytes_per_block: u64,
    reserved1: u32,
    uuid: [2]u64,
};

pub const Entry = struct {
    directory_id: u64,
    type: u1,
    name: [201]u8,
    atime: u64,
    mtime: u64,
    permissions: u16,
    owner_id: u16,
    group_id: u16,
    ctime: u64,
    starting_block: u64,
    file_size: u64,
};
