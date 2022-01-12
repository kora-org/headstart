const std = @import("std");
const heap = @import("std").heap;

var buffer: [4096]u8 = undefined;
var fba = heap.FixedBufferAllocator.init(&buffer);
pub const allocator = fba.allocator();
