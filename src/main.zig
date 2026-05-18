const microzig = @import("microzig");
const gpioc = microzig.chip.peripherals.GPIOC;
const rcc = microzig.chip.peripherals.RCC;

pub fn main() !void {
    rcc.AHB1ENR.modify(.{ .GPIOCEN = 1 });
    gpioc.MODER.modify(.{ .@"MODER[13]" = .Output });

    while (true) {
        gpioc.ODR.modify(.{ .@"ODR[13]" = .Low });
        delay(1000000);
        gpioc.ODR.modify(.{ .@"ODR[13]" = .High });
        delay(1000000);
    }
}

fn delay(cycles: u32) void {
    var i: u32 = 0;
    while (i < cycles) : (i += 1) {
        asm volatile ("nop");
    }
}
