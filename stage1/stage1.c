#include "vga.h"

void start(void) {
    vga_initialize();
    vga_writestring("Hello Bootloader World!");
}
