# XeptoBoot
A small 2-staged bootloader written in Zig. In the (currently not working)
BIOS version, it first boots in the first stage (or how XeptoBoot calls it,
stage0) and then switches to the protected mode and boots the second stage.
Meanwhile in the UEFI version, it will boot straight to the second stage.

## Progress
- [X] Made a hello world bootloader
- [ ] Add a basic kernel loader
- [ ] Add Stivale2 boot protocol support
- [ ] Add Multiboot boot protocol support
- [ ] Add Linux boot protocol support
