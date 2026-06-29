all:
    just build
    just obj-copy

build jobs="4":
    zig build -j{{jobs}}
    @echo "====================="
    @echo "BUILT SUCCESSFULLY"

clean:
    rm -rf zig-out

clean-all:
    @just clean
    rm -rf .zig-cache zig-pkg

disasm:
    aarch64-linux-gnu-objdump -d zig-out/firmware/blink.elf

check-size:
    @echo "size is $(ls -la zig-out/firmware/blink.bin | awk '{print $5}') bytes"

obj-copy:
    arm-none-eabi-objcopy -O binary zig-out/firmware/blink.elf zig-out/firmware/blink.bin
    @echo "====================="
    @echo "COPIED SUCCESSFULLY"
    @just check-size

upload-usb:
    sudo dfu-util -a 0 -d 0483:df11 -s 0x08000000:leave -D zig-out/firmware/blink.bin

# TODO: implement
# upload-uart:
# upload-stlink: