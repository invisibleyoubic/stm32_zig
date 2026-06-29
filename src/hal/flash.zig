const microzig = @import("microzig");

const flash = microzig.chip.peripherals.FLASH;

pub const Flash = struct {
    // TODO: function argument
    pub fn set_latency() void {
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
    }

    pub fn enable_cache() void {
        flash.ACR.modify(
            .{
                .PRFTEN = 1,
                .ICEN = 1,
                .DCEN = 1,
            },
        );
    }

    pub fn clear_cache() void {
        flash.ACR.modify(
            .{
                .ICRST = 1,
                .DCRST = 1,
            },
        );

        flash.ACR.modify(
            .{
                .ICRST = 0,
                .DCRST = 0,
            },
        );
    }
};
