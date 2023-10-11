#include <stdint.h>
#include <stddef.h>

typedef struct {
    void (*print)(char *);
} headstart_hdr;

void _start(headstart_hdr *headstart) {
    headstart->print("Hello world.\n");
    while (1)
        asm volatile ("hlt");
}
