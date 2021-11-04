#include "io.h"
#include "vga.h"

void stage1_entry(void) {
    outb(0xe9, 't');
    vga_initialize();
    vga_writestring("Hello Bootloader World!");
    while (1)
        asm("hlt");
}
