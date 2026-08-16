const microzig = @import("microzig");

const rcc = microzig.chip.peripherals.RCC;

pub const RCC = struct {
    // TODO: function argument with target frequency and source
    pub fn set_up_clock_speed() void {
        rcc.CR.modify_one("PLLON", 0);

        // VCO = (HSI speed * (PLLN / PLLM)) = 16 * (192 / 16) = 192 MHz
        // VCO / PLLP = 192 / 2 = 96 MHz
        rcc.PLLCFGR.write(
            .{
                .PLLM = .Div16,
                .PLLN = .Mul192,
                .PLLP = .Div2,
                .PLLSRC = .HSI, // 16 MHz
                .PLLQ = .Div4,
                .PLLR = .Div4,
            },
        );

        while (rcc.CR.read().HSIRDY == 0) {}
        rcc.CR.modify_one("PLLON", 1);
        while (rcc.CR.read().PLLRDY == 0) {}
        rcc.CFGR.modify_one("SW", .PLL1_P);
        while (rcc.CFGR.read().SWS != .PLL1_P) {}
        rcc.CFGR.modify_one("PPRE1", .Div2);
        rcc.CFGR.modify_one("PPRE2", .Div1);
    }

    // TODO: specify peripheral to enable
    pub fn enable_AHB1() void {
        rcc.AHB1ENR.modify(
            .{
                .GPIOBEN = 1,
                .GPIOCEN = 1,
            },
        );
    }

    // TODO: specify peripheral to enable
    pub fn enable_APB1() void {
        rcc.APB1ENR.modify(
            .{
                .I2C1EN = 1,
            },
        );
    }
};
