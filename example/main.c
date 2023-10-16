#include <stdint.h>
#include <stddef.h>
#include "limine.h"

static volatile struct limine_framebuffer_request framebuffer_request = {
    .id = LIMINE_FRAMEBUFFER_REQUEST,
    .revision = 0
};

void _start(void) {
    if (framebuffer_request.response == NULL || framebuffer_request.response->framebuffer_count < 1)
        while (1)
            asm volatile ("hlt");

    struct limine_framebuffer *framebuffer = framebuffer_request.response->framebuffers[0];
    for (size_t i = 0; i < 100; i++) {
        volatile uint32_t *fb_ptr = framebuffer->address;
        fb_ptr[i * framebuffer->width + i] = 0xffffffff;
    }

    while (1)
        asm volatile ("hlt");
}