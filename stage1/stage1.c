#include "io.h"
#include "vga.h"

void _start(void) {
    outb(0xe9, 't');
    vga_initialize();
    vga_writestring("Hello Bootloader World!");
    while (1)
        asm("hlt");
}
