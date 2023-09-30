#include <stdint.h>
#include <stddef.h>

typedef struct {
	void (*print)(wchar_t *);
} headstart_hdr;

void _start(headstart_hdr *headstart) {
    headstart->print(L"Hello world.\r\n");
}
