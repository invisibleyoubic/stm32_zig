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

    pub inline fn setPixel(self: *Display, x: u16, y: u16) void {
        setPixelImpl(self, x, y, true);
    }

    pub inline fn unsetPixel(self: *Display, x: u16, y: u16) void {
        setPixelImpl(self, x, y, false);
    }

    fn setPixelImpl(self: *Display, x: u16, y: u16, color: bool) void {
        if (x >= self.width or y >= self.height)
            return;

        const bit_offset: u16 = y % 8;
        const byte_index: u16 = (@as(u16, y / 8) * self.width) + x;
        const mask = @as(u8, 1) << @intCast(bit_offset);
        if (color) {
            self.buffer[byte_index] |= mask;
        } else {
            self.buffer[byte_index] &= ~mask;
        }
    }

    // Bresenham's line algorithm
    pub fn drawLine(self: *Display, x0_in: u16, y0_in: u16, x1_in: u16, y1_in: u16) void {
        var x0 = @as(i16, @intCast(x0_in));
        var y0 = @as(i16, @intCast(y0_in));
        const x1 = @as(i16, @intCast(x1_in));
        const y1 = @as(i16, @intCast(y1_in));

        const dx: i16 = if (x0 > x1) x0 - x1 else x1 - x0;
        const dy: i16 = if (y0 > y1) y0 - y1 else y1 - y0;

        const sx: i16 = if (x0 < x1) 1 else -1;
        const sy: i16 = if (y0 < y1) 1 else -1;

        var err: i16 = dx - dy;

        while (true) {
            self.setPixel(@intCast(x0), @intCast(y0));
            if (x0 == x1 and y0 == y1) {
                break;
            }

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x0 += sx;
            }
            if (e2 < dx) {
                err += dx;
                y0 += sy;
            }
        }
    }
};
