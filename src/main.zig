const microzig = @import("microzig");

const gpiob = microzig.chip.peripherals.GPIOB;
const gpioc = microzig.chip.peripherals.GPIOC;
const i2c = microzig.chip.peripherals.I2C1;

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

    hal.Timer.init();

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

    hal.Timer.delay(3);

    // TODO: move to Display
    init_display();

    var i2c_display = hal.Display.init(&display_buffer, 128, 64);

    i2c_display.clear();

    // i2c_display.drawLine(0, 0, 127, 63);
    // i2c_display.drawLine(127, 0, 0, 63);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    // i2c_display.drawLine(0, 0, 0, 63);
    // i2c_display.drawLine(127, 0, 127, 63);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    // i2c_display.drawLine(0, 0, 15, 45);
    // i2c_display.drawLine(127, 0, 0, 10);

    // i2c_display.drawCicrle(100, 31, 30);
    // i2c_display.drawCicrle(63, 31, 30);
    // i2c_display.drawCicrle(27, 31, 15);

    // i2c_display.drawEllipse(63, 31, 30, 20);
    // i2c_display.drawEllipse(63, 31, 15, 30);

    // i2c_display.fillCicrle(63, 31, 30);
    // i2c_display.fillEllipse(63, 31, 15, 30);

    // i2c_display.drawEllipse(63, 31, 30, 20);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    // i2c_display.fillEllipse(63, 31, 30, 20);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    // i2c_display.clear();
    // i2c_display.drawCicrle(63, 31, 10);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    // i2c_display.fillCicrle(63, 31, 10);

    // send_buffer(&display_buffer);
    // blink(1, 1);

    for (0..10) |i| {
        i2c_display.setPixel(@intCast(i), 0);
        i2c_display.drawDigit(@intCast(5 * i), 10, @intCast(i));
        i2c_display.drawCicrle(@intCast(5 + 10 * i), 30, 5);
        i2c_display.drawLine(@intCast(127 - i), 0, @intCast(127 - i), @intCast(15 - i));
        send_buffer(&display_buffer);
    }

    blink(3, 500);
    i2c_display.clear();

    var code: u8 = 32;
    var x: u16 = 0;
    var y: u16 = 0;
    while (code < 127) : (code += 1) {
        i2c_display.drawChar(@intCast((5 * x)), @intCast((8 * y) + 1), code);
        if (x + 2 > 24) {
            x = 0;
            y += 1;
        } else {
            x += 2;
        }
        send_buffer(&display_buffer);
    }

    while (true) {
        blink(1, 1000);
    }
}

inline fn blink(count: u32, del: u32) void {
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        gpioc.ODR.modify(.{ .@"ODR[13]" = .Low });
        hal.Timer.delay(del);
        gpioc.ODR.modify(.{ .@"ODR[13]" = .High });
        hal.Timer.delay(del);
    }
}

fn init_display() void {
    i2c.CR1.modify_one("START", 1);
    while (i2c.SR1.read().START == 0) {}

    i2c.DR.write(.{ .DR = 0x78 });
    while (i2c.SR1.read().ADDR == 0) {}
    _ = i2c.SR2.read();

    const commands = [_]u8{ 0x00, 0x8D, 0x14, 0xAF, 0x20, 0x00, 0x21, 0x00, 127, 0x22, 0x00, 7, 0xA8, 0x3F };
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

// TODO: move to display or i2c
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
