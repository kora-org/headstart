#include <efi.h>
#include <efilib.h>
#include <stdbool.h>
#include <keyboard.h>
#include <uefi_common.h>
#include <elf_loader.h>

EFI_HANDLE *ImageHandle;

EFI_STATUSefi_main (EFI_HANDLE _ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    ST = SystemTable;
    ImageHandle = _ImageHandle;
    BS = SystemTable->BootServices;

    EFI_INPUT_KEY *input;
    ST->ConOut->Reset(ST->ConOut, 0);
    ST->ConIn->Reset(ST->ConIn, 0);
    /*ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGREEN);
    ST->ConOut->OutputString(ST->ConOut, L"\r\n  XeptoBoot ");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY);
    ST->ConOut->OutputString(ST->ConOut, L"0.1\r\n\r\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_WHITE);
    ST->ConOut->OutputString(ST->ConOut, L"> Test\r\n");
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGRAY);
    ST->ConOut->OutputString(ST->ConOut, L"  Test\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"  Test\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"\r\n---\r\nthe manu above is currently not usable\r\n");
    ST->ConOut->OutputString(ST->ConOut, L"heres a keyboard test\r\n");
    
    for (;;) {
        get_keystroke(input);
        if (input->UnicodeChar == CHAR_CARRIAGE_RETURN)
            ST->ConOut->OutputString(ST->ConOut, L"\r\n");
        else if (input->UnicodeChar == CHAR_BACKSPACE)
            ST->ConOut->OutputString(ST->ConOut, L"\b");

        ST->ConOut->OutputString(ST->ConOut, &input->UnicodeChar);
    }*/
    ST->ConOut->OutputString(ST->ConOut, L"Loading kernel.elf...\r\n");
    if (load_elf(L"kernel.elf") != EFI_SUCCESS)
        ST->ConOut->OutputString(ST->ConOut, L"[panic] Kernel failed to load.\n\r");

    while (true)
        asm("hlt");

    return EFI_SUCCESS;
}
