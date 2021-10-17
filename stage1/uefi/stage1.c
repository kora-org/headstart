#include <uefi.h>
#include <stdbool.h>

int main(int argc, char **argv) {
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGREEN);
    printf("\n  XeptoBoot ");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY);
    printf("0.1\n\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_WHITE);
    printf("> Test\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY);
    printf("  Test\n");
    printf("  Test\n");
    while (true)
        asm("hlt");
    return 0;
}
