const microzig = @import("microzig");

const gpioa = microzig.chip.peripherals.GPIOA;
const gpiob = microzig.chip.peripherals.GPIOB;
const gpioc = microzig.chip.peripherals.GPIOC;
const i2c = microzig.chip.peripherals.I2C1;
const syscfg = microzig.chip.peripherals.SYSCFG;
const exti = microzig.chip.peripherals.EXTI;
const tim9 = microzig.chip.peripherals.TIM9;

const hal = @import("hal/hal.zig");

var display_buffer: [1024]u8 = @splat(0x00);

pub const panic = microzig.panic;

pub const std_options = microzig.std_options(.{});

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .EXTI0 = .{ .c = EXTI0_handler },
        .TIM1_BRK_TIM9 = .{ .c = TIM9_handler },
    },
};

var is_available: bool = false;
pub fn EXTI0_handler() callconv(.c) void {
    if (exti.PR.read().@"LINE[0]" == 1) {
        exti.PR.write_raw(1);
    }
}

pub fn TIM9_handler() callconv(.c) void {
    if (tim9.SR.read().UIF == 1) {
        tim9.SR.modify(.{ .UIF = 0 });
        gpioc.ODR.modify(.{ .@"ODR[13]" = .High });
    }
    if (tim9.SR.read().@"CCIF[0]" == 1) {
        tim9.SR.modify(.{ .@"CCIF[0]" = 0 });
        gpioc.ODR.modify(.{ .@"ODR[13]" = .Low });
    }
}

pub fn main() !void {
    const flash = hal.Flash;
    const rcc = hal.RCC;

    flash.set_latency();

    rcc.set_up_clock_speed();

    flash.clear_cache();
    flash.enable_cache();

    rcc.enable_AHB1();
    rcc.enable_APB1();
    rcc.enable_APB2();

    hal.Timer.init();

    gpioa.MODER.modify(.{ .@"MODER[0]" = .Input });
    gpioa.PUPDR.modify(.{ .@"PUPDR[0]" = .PullUp });

    gpioc.MODER.modify_one("MODER[13]", .Output);
    gpioc.OTYPER.modify_one("OT[13]", .PushPull);

    // gpio b
    gpiob.MODER.modify(.{
        .@"MODER[6]" = .Alternate,
        .@"MODER[7]" = .Alternate,
    });

    gpiob.AFR[0].modify(.{
        .@"AFR[6]" = 0b0100,
        .@"AFR[7]" = 0b0100,
    });

    // interrupt for user button
    syscfg.EXTICR[0].modify(.{ .@"EXTI[0]" = 0b0000 });

    exti.IMR.modify(.{ .@"LINE[0]" = 1 });
    exti.FTSR.modify(.{ .@"LINE[0]" = 1 });
    exti.RTSR.modify(.{ .@"LINE[0]" = 0 });

    exti.PR.write_raw(1);
    microzig.interrupt.enable(.EXTI0);

    // i2c
    i2c.CR1.modify_one("PE", 0);
    i2c.CR2.modify_one("FREQ", 50);
    i2c.CCR.modify_one("CCR", 250);
    i2c.TRISE.modify_one("TRISE", 51);
    i2c.CR1.modify_one("PE", 1);

    // tim9
    // ( psc + 1 * arr ) / fapb
    tim9.PSC = 2000 - 1;
    tim9.ARR.modify(.{ .ARR = 960 });

    tim9.DIER.modify(.{
        .UIE = 1,
        .@"CCIE[0]" = 1,
    });
    tim9.CNT.modify(.{ .CNT = 0 });
    microzig.interrupt.enable(.TIM1_BRK_TIM9);

    tim9.CR1.modify(.{ .CEN = 1 });

    while (true) {
        // blink(1, 1000);
        microzig.cpu.wfi();
        for (0..tim9.ARR.read().ARR) |i| {
            tim9.CCR[0].modify(.{ .CCR = @as(u16, @intCast(i)) });
            hal.Timer.delay(2);
        }
        var i: u16 = tim9.ARR.read().ARR;
        while (i >= 0) : (i -= 1) {
            tim9.CCR[0].modify(.{ .CCR = @as(u16, @intCast(i)) });
            hal.Timer.delay(2);
            if (i == 0) break;
        }
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
