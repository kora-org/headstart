#include "io.h"
#include "vga.h"

void start(void) {
    outb(0xe9, 't');
    vga_initialize();
    vga_writestring("Hello Bootloader World!");
}
