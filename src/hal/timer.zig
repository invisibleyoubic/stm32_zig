const microzig = @import("microzig");

const sysTick = microzig.cpu.peripherals.systick;

pub const Timer = struct {
    // TODO: specify HSI or HSE
    pub fn init() void {
        sysTick.LOAD.modify_one("RELOAD", 16_000 - 1);
        sysTick.CTRL.write(.{
            .ENABLE = 1,
            .CLKSOURCE = 1,
            .TICKINT = 0,
            .COUNTFLAG = 0,
        });
    }

    pub fn delay(ms: u32) void {
        for (0..(96 / 16)) |_| {
            sysTick.VAL.modify_one("CURRENT", 0);
            for (0..ms) |_| {
                while (sysTick.CTRL.read().COUNTFLAG == 0) {}
            }
        }
    }
};
