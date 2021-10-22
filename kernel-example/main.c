#include <stdint.h>
#include <stddef.h>

typedef struct {
	void (*print)(wchar_t *);
} xeptoboot_hdr;

void _start(xeptoboot_hdr *xeptoboot) {
    xeptoboot->print(L"Hello world.\r\n");
}
