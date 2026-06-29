const microzig = @import("microzig");

const gpiob = microzig.chip.peripherals.GPIOB;
const gpioc = microzig.chip.peripherals.GPIOC;
// const rcc = microzig.chip.peripherals.RCC;
const i2c = microzig.chip.peripherals.I2C1;
// const flash = microzig.chip.peripherals.FLASH;

const hal = @import("hal/hal.zig");

var display_buffer: [1024]u8 = @splat(0x00);

pub fn main() !void {
    const flash = hal.Flash;
    const rcc = hal.RCC;

    flash.set_latency();

    rcc.set_up_clock_speed();

    flash.clear_cache();
    flash.enable_cache();

    rcc.enable_AHB1();
    rcc.enable_APB1();

    gpioc.MODER.modify_one("MODER[13]", .Output);
    gpioc.OTYPER.modify_one("OT[13]", .PushPull);

    // gpio b
    gpiob.MODER.modify(
        .{
            .@"MODER[6]" = .Alternate,
            .@"MODER[7]" = .Alternate,
        },
    );

    gpiob.AFR[0].modify(
        .{
            .@"AFR[6]" = 0b0100,
            .@"AFR[7]" = 0b0100,
        },
    );

    // i2c
    i2c.CR1.modify_one("PE", 0);
    i2c.CR2.modify_one("FREQ", 50);
    i2c.CCR.modify_one("CCR", 250);
    i2c.TRISE.modify_one("TRISE", 51);
    i2c.CR1.modify_one("PE", 1);

    var wait: u32 = 0;
    while (wait < 16_000_000 * 2) : (wait += 1) {
        asm volatile ("" ::: .{ .memory = true });
    }

    init_display();

    // fill_display();
    clear_display();

    // for (100..120) |x| {
    //     for (32..40) |y| {
    //         draw_pixel(@intCast(x), @intCast(y));
    //     }
    // }
    // send_buffer(&display_buffer);

    // blink(2, 16_000_000);

    // for (10..60) |x| {
    //     for (50..63) |y| {
    //         draw_pixel(@intCast(x), @intCast(y));
    //     }
    // }
    // send_buffer(&display_buffer);

    // draw_pixel(0, 0);
    // draw_pixel(63, 0);
    // draw_pixel(127, 0);
    // draw_pixel(0, 3);
    // draw_pixel(63, 3);
    // draw_pixel(127, 3);
    // draw_pixel(0, 7);
    // draw_pixel(63, 7);
    // draw_pixel(127, 7);
    // draw_pixel(0, 10);
    // draw_pixel(63, 10);
    // draw_pixel(127, 10);
    // draw_pixel(0, 13);
    // draw_pixel(63, 13);
    // draw_pixel(127, 13);
    // draw_pixel(0, 17);
    // draw_pixel(63, 17);
    // draw_pixel(127, 17);

    // // var x: u8 = 0;
    // for (0..127) |y| {
    //     delay(8_000_000);
    //     draw_pixel(0, @intCast(y));
    //     send_buffer(&display_buffer);
    //     // if (y % 16 == 0) {
    //     //     x += 1;
    //     //     // clear_display();
    //     // }
    // }

    // display_buffer[1023] = 0b10000001;
    // display_buffer[1020] = 0xFF;
    // display_buffer[1017] = 0xFF;
    // display_buffer[1014] = 0xFF;
    // display_buffer[1011] = 0xFF;
    // display_buffer[1009] = 0xFF;
    // display_buffer[1006] = 0xFF;
    // display_buffer[1003] = 0xFF;
    // display_buffer[1000] = 0xFF;
    // send_buffer(&display_buffer);

    // blink(1, 16_000_000);

    // display_buffer[0] = 0b10000001;
    // display_buffer[3] = 0xFF;
    // display_buffer[6] = 0xFF;
    // display_buffer[9] = 0xFF;
    // display_buffer[11] = 0xFF;
    // display_buffer[14] = 0xFF;
    // display_buffer[17] = 0xFF;
    // display_buffer[20] = 0xFF;
    // display_buffer[23] = 0xFF;
    // send_buffer(&display_buffer);

    display_buffer[0] = 0xFF;
    display_buffer[512] = 0xFF;
    display_buffer[700] = 0xFF;
    send_buffer(&display_buffer);

    while (true) {
        blink(1, 16_000_000);
    }
}

fn delay(cycles: u32) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

inline fn blink(count: u32, del: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        gpioc.ODR.modify(.{ .@"ODR[13]" = .Low });
        delay(del);
        gpioc.ODR.modify(.{ .@"ODR[13]" = .High });
        delay(del);
    }
}

fn init_display() void {
    i2c.CR1.modify_one("START", 1);
    while (i2c.SR1.read().START == 0) {}

    i2c.DR.write(.{ .DR = 0x78 });
    while (i2c.SR1.read().ADDR == 0) {}
    _ = i2c.SR2.read();

    const commands = [_]u8{ 0x00, 0x8D, 0x14, 0xAF, 0x20, 0x00, 0x21, 0x00, 127, 0x22, 0x00, 7, 0xA8, 0x38 };
    // const commands = [_]u8{ 0x00, 0x8D, 0x14, 0xAF, 0x20, 0x00, 0x21, 0x00, 127, 0x22, 0x00, 7 };
    for (commands) |cmd| {
        while (i2c.SR1.read().TXE == 0) {}
        i2c.DR.write(.{ .DR = cmd });
    }

    while (true) {
        const sr1 = i2c.SR1.read();
        if ((sr1.TXE == 0) or (sr1.BTF == 0))
            continue;
        break;
    }
    i2c.CR1.modify_one("STOP", 1);
}

fn send_buffer(buffer: []const u8) void {
    i2c.CR1.modify_one("START", 1);
    while (i2c.SR1.read().START == 0) {}

    i2c.DR.write(.{ .DR = 0x78 });
    while (i2c.SR1.read().ADDR == 0) {}
    _ = i2c.SR2.read();

    while (i2c.SR1.read().TXE == 0) {}
    i2c.DR.write(.{ .DR = 0x40 });

    for (buffer) |data| {
        while (i2c.SR1.read().TXE == 0) {}
        i2c.DR.write(.{ .DR = data });
    }

    while (true) {
        const sr1 = i2c.SR1.read();
        if ((sr1.TXE == 0) or (sr1.BTF == 0))
            continue;
        break;
    }
    i2c.CR1.modify_one("STOP", 1);
}

fn clear_display() void {
    display_buffer = @splat(0x00);
    send_buffer(&display_buffer);
}

fn fill_display() void {
    display_buffer = @splat(0xFF);
    send_buffer(&display_buffer);
}

fn draw_pixel(x: u8, y: u8) void {
    const byte_index: u16 = x + ((y / 8) * 128);
    const bit_index: u16 = y % 8;

    display_buffer[byte_index] |= (@as(u8, 1) << @intCast(bit_index));
}
