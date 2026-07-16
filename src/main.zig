const microzig = @import("microzig");

const gpiob = microzig.chip.peripherals.GPIOB;
const gpioc = microzig.chip.peripherals.GPIOC;
// const rcc = microzig.chip.peripherals.RCC;
const i2c = microzig.chip.peripherals.I2C1;
// const flash = microzig.chip.peripherals.FLASH;

const hal = @import("hal/hal.zig");
const display = @import("hal/display.zig");

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

    // TODO: move to Display
    init_display();

    var i2c_display = display.Display.init(&display_buffer, 128, 64);

    i2c_display.clear();

    // i2c_display.drawLine(0, 0, 127, 63);
    // i2c_display.drawLine(127, 0, 0, 63);

    // send_buffer(&display_buffer);
    // blink(1, 16_000_000);

    // i2c_display.drawLine(0, 0, 0, 63);
    // i2c_display.drawLine(127, 0, 127, 63);

    // send_buffer(&display_buffer);
    // blink(1, 16_000_000);

    // i2c_display.drawLine(0, 0, 15, 45);
    // i2c_display.drawLine(127, 0, 0, 10);

    i2c_display.drawCicrle(100, 31, 30);
    i2c_display.drawCicrle(63, 31, 10);
    i2c_display.drawCicrle(27, 31, 15);

    send_buffer(&display_buffer);
    blink(1, 16_000_000);

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
