const microzig = @import("microzig");

const gpiob = microzig.chip.peripherals.GPIOB;
const gpioc = microzig.chip.peripherals.GPIOC;
const rcc = microzig.chip.peripherals.RCC;
const i2c = microzig.chip.peripherals.I2C1;
const flash = microzig.chip.peripherals.FLASH;

pub fn main() !void {
    // setup clock
    flash.ACR.write(
        .{
            .LATENCY = .WS3,
            .PRFTEN = 0,
            .ICEN = 0,
            .DCEN = 0,
            .ICRST = 0,
            .DCRST = 0,
        },
    );

    rcc.PLLCFGR.write(
        .{
            .PLLM = .Div16,
            .PLLN = .Mul192,
            .PLLP = .Div2,
            .PLLSRC = .HSI,
            .PLLQ = .Div4,
            .PLLR = .Div4,
        },
    );

    while (rcc.CR.read().HSIRDY == 0) {}

    rcc.CR.modify_one("PLLON", 1);

    while (rcc.CR.read().PLLRDY == 0) {}

    rcc.CFGR.modify_one("SW", .PLL1_P);

    while (rcc.CFGR.read().SWS != .PLL1_P) {}

    // gpio c
    rcc.AHB1ENR.modify(
        .{
            .GPIOBEN = 1,
            .GPIOCEN = 1,
        },
    );

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

    blink(1);

    // i2c
    i2c.CR1.modify_one("PE", 0);
    rcc.APB1ENR.modify_one("I2C1EN", 1);
    i2c.CR2.modify_one("FREQ", 50);
    i2c.CCR.modify_one("CCR", 250);
    i2c.TRISE.modify_one("TRISE", 51);
    i2c.CR1.modify_one("PE", 1);

    var wait: u32 = 0;
    while (wait < 16_000_000 * 2) : (wait += 1) {
        asm volatile ("" ::: .{ .memory = true });
    }

    init_display();

    while (true) {
        blink(1);
    }
}

fn delay(cycles: u32) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn blink(count: u32) void {
    var i: u32 = 0;
    const del = 16_000_000;
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

    const commands = [_]u8{ 0x00, 0x8D, 0x14, 0xAF };
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
