const std = @import("std");
const font = @import("font.zig");

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

    // Bresenham's circle algorithm
    pub fn drawCicrle(self: *Display, x0_in: u16, y0_in: u16, r: u16) void {
        var x: i16 = 0;
        var y: i16 = @as(i16, @intCast(r));
        var err: i16 = 3 - 2 * @as(i16, @intCast(r));

        while (x <= y) {
            drawCirclePlot(self, x0_in, y0_in, @intCast(x), @intCast(y));
            if (err >= 0) {
                err = err + 4 * (x - y) + 10;
                y -= 1;
            } else {
                err = err + 4 * x + 6;
            }
            x += 1;
        }
    }

    inline fn drawCirclePlot(self: *Display, cx: u16, cy: u16, x: u16, y: u16) void {
        self.setPixel(cx + x, cy + y);
        self.setPixel(cx - x, cy + y);
        self.setPixel(cx + x, cy - y);
        self.setPixel(cx - x, cy - y);
        self.setPixel(cx + y, cy + x);
        self.setPixel(cx - y, cy + x);
        self.setPixel(cx + y, cy - x);
        self.setPixel(cx - y, cy - x);
    }

    pub fn fillCicrle(self: *Display, x0_in: u16, y0_in: u16, r: u16) void {
        var x: i16 = 0;
        var y: i16 = @as(i16, @intCast(r));
        var err: i16 = 3 - 2 * @as(i16, @intCast(r));

        while (x <= y) {
            fillCirclePlot(self, x0_in, y0_in, @intCast(x), @intCast(y));
            if (err >= 0) {
                err = err + 4 * (x - y) + 10;
                y -= 1;
            } else {
                err = err + 4 * x + 6;
            }
            x += 1;
        }
    }

    inline fn fillCirclePlot(self: *Display, cx: u16, cy: u16, x: u16, y: u16) void {
        if (cx >= x) {
            self.drawLine(@intCast(cx - x), @intCast(cy + y), @intCast(cx + x), @intCast(cy + y));
            self.drawLine(@intCast(cx - x), @intCast(cy - y), @intCast(cx + x), @intCast(cy - y));
        } else {
            self.drawLine(0, @intCast(cy + y), @intCast(cx + x), @intCast(cy + y));
            self.drawLine(0, @intCast(cy - y), @intCast(cx + x), @intCast(cy - y));
        }

        // Пара 2: линии ближе к краям (поуже)
        if (cx >= y) {
            self.drawLine(@intCast(cx - y), @intCast(cy + x), @intCast(cx + y), @intCast(cy + x));
            self.drawLine(@intCast(cx - y), @intCast(cy - x), @intCast(cx + y), @intCast(cy - x));
        } else {
            self.drawLine(0, @intCast(cy + x), @intCast(cx + y), @intCast(cy + x));
            self.drawLine(0, @intCast(cy - x), @intCast(cx + y), @intCast(cy - x));
        }
    }

    // Bresenham's ellipse algorithm
    pub fn drawEllipse(self: *Display, x0_in: u16, y0_in: u16, a_in: u16, b_in: u16) void {
        const a: i32 = @intCast(a_in);
        const b: i32 = @intCast(b_in);

        var x: i32 = 0;
        var y: i32 = b;

        const a2: i32 = a * a;
        const b2: i32 = b * b;

        const two_a2: i32 = 2 * a2;
        const two_b2: i32 = 2 * b2;

        var px: i32 = 0;
        var py: i32 = two_a2 * y;

        // region 1
        // original function : b2 - a2 * b + 0.25 * a2
        // 4 - to get rid of 0.25
        var p: i32 = 4 * b2 - 4 * a2 * b + a2;

        while (px < py) {
            self.drawEllipsePlot(x0_in, y0_in, @intCast(x), @intCast(y));

            var delta_y: i32 = 0;
            if (p >= 0) {
                y -= 1;
                py -= two_a2;
                delta_y = py;
            }

            p += 4 * px + 6 * b2 - 4 * delta_y;
            x += 1;
            px += two_b2;
        }

        // region 2
        // original formula: b2 * (x + 0.5)^2 + a2 * (y - 1)^2 - a2 * b2
        p = b2 * (x * x + x) + a2 * (y - 1) * (y - 1) - a2 * b2;

        while (y >= 0) {
            self.drawEllipsePlot(x0_in, y0_in, @intCast(x), @intCast(y));

            var delta_x: i32 = 0;
            if (p < 0) {
                x += 1;
                px += two_b2;
                delta_x = px;
            }

            y -= 1;
            py -= two_a2;
            p += a2 - py + delta_x;
        }
    }

    inline fn drawEllipsePlot(self: *Display, cx: u16, cy: u16, x: u16, y: u16) void {
        self.setPixel(cx + x, cy + y);
        self.setPixel(cx - x, cy + y);
        self.setPixel(cx + x, cy - y);
        self.setPixel(cx - x, cy - y);
    }

    pub fn fillEllipse(self: *Display, x0_in: u16, y0_in: u16, a_in: u16, b_in: u16) void {
        const a: i32 = @intCast(a_in);
        const b: i32 = @intCast(b_in);

        var x: i32 = 0;
        var y: i32 = b;

        const a2: i32 = a * a;
        const b2: i32 = b * b;

        const two_a2: i32 = 2 * a2;
        const two_b2: i32 = 2 * b2;

        var px: i32 = 0;
        var py: i32 = two_a2 * y;

        // region 1
        // original function : b2 - a2 * b + 0.25 * a2
        // 4 - to get rid of 0.25
        var p: i32 = 4 * b2 - 4 * a2 * b + a2;

        while (px < py) {
            self.fillEllipsePlot(x0_in, y0_in, @intCast(x), @intCast(y));

            var delta_y: i32 = 0;
            if (p >= 0) {
                y -= 1;
                py -= two_a2;
                delta_y = py;
            }

            p += 4 * px + 6 * b2 - 4 * delta_y;
            x += 1;
            px += two_b2;
        }

        // region 2
        // original formula: b2 * (x + 0.5)^2 + a2 * (y - 1)^2 - a2 * b2
        p = b2 * (x * x + x) + a2 * (y - 1) * (y - 1) - a2 * b2;

        while (y >= 0) {
            self.fillEllipsePlot(x0_in, y0_in, @intCast(x), @intCast(y));

            var delta_x: i32 = 0;
            if (p < 0) {
                x += 1;
                px += two_b2;
                delta_x = px;
            }

            y -= 1;
            py -= two_a2;
            p += a2 - py + delta_x;
        }
    }

    inline fn fillEllipsePlot(self: *Display, cx: u16, cy: u16, x: u16, y: u16) void {
        if (cx >= x) {
            self.drawLine(@intCast(cx - x), @intCast(cy + y), @intCast(cx + x), @intCast(cy + y));
            self.drawLine(@intCast(cx - x), @intCast(cy - y), @intCast(cx + x), @intCast(cy - y));
        } else {
            self.drawLine(0, @intCast(cy + y), @intCast(cx + x), @intCast(cy + y));
            self.drawLine(0, @intCast(cy - y), @intCast(cx + x), @intCast(cy - y));
        }
    }

    pub fn drawDigit(self: *Display, x: u16, y: u16, digit: u8) void {
        if (digit > 9)
            return;

        const data = font.font_5x7[16 + digit];
        for (data, 0..) |bytes, column| {
            var row: u16 = 0;
            while (row < 8) : (row += 1) {
                const mask = @as(u8, 1) << @intCast(row);
                if ((bytes & mask) != 0) {
                    self.setPixel(x + @as(u16, @intCast(column)), y + row);
                }
            }
        }
    }

    pub fn drawChar(self: *Display, x: u16, y: u16, ch: u8) void {
        if (ch < 32 or ch > 126) return;

        const index = ch - 32;
        const data = font.font_5x7[index];

        for (data, 0..) |bytes, column| {
            var row: u16 = 0;
            while (row < 8) : (row += 1) {
                const mask = @as(u8, 1) << @intCast(row);
                if ((bytes & mask) != 0) {
                    self.setPixel(x + @as(u16, @intCast(column)), y + row);
                }
            }
        }
    }

    pub fn drawString(self: *Display, x: u16, y: u16, str: []const u8) void {
        var cursor = x;

        for (str) |ch| {
            self.drawChar(cursor, y, ch);
            // font size is 7x5
            // TODO:
            cursor += 6;
        }
    }
};
