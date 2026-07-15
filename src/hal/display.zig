const std = @import("std");

pub const Display = struct {
    width: u16,
    height: u16,
    buffer: []u8,

    pub fn init(buffer: []u8, width: u16, height: u16) Display {
        return .{
            .width = width,
            .height = height,
            .buffer = buffer,
        };
    }

    pub inline fn clear(self: *Display) void {
        @memset(self.buffer[0..], 0x00);
    }

    pub inline fn fill(self: *Display) void {
        @memset(self.buffer[0..], 0xFF);
    }

    pub fn setPixel(self: *Display, x: u16, y: u16) void {
        if (x >= self.width or y >= self.height)
            return;

        const bit_offset: u16 = y % 8;
        const byte_index: u16 = (@as(u16, y / 8) * 128) + x;
        self.buffer[byte_index] |= (@as(u8, 1) << @intCast(bit_offset));
    }

    pub fn unsetPixel(self: *Display, x: u16, y: u16) void {
        if (x >= self.width or y >= self.height)
            return;

        const bit_offset: u16 = y % 8;
        const byte_index: u16 = (@as(u16, y / 8) * 128) + x;
        self.buffer[byte_index] &= ~(@as(u8, 1) << @intCast(bit_offset));
    }
};
