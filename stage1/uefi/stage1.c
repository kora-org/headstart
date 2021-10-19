#include <efi.h>
#include <efilib.h>
#include <stdbool.h>

EFI_SYSTEM_TABLE *ST;
EFI_SYSTEM_TABLE *gST;

EFI_STATUS kbhit(struct EFI_INPUT_KEY *Key) {
    return ST->ConIn->ReadKeyStroke(ST->ConIn, Key);
}

EFI_STATUS get_keystroke(struct EFI_INPUT_KEY *Key) {
    //ST->ConIn->WaitForKey(0);
    return ST->ConIn->ReadKeyStroke(ST->ConIn, Key);
}

EFI_STATUSefi_main (EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    EFI_INPUT_KEY *input;
    ST = SystemTable;
    gST = SystemTable;
    ST->ConOut->Reset(ST->ConOut, 0);
    ST->ConIn->Reset(ST->ConIn, 0);
    ST->ConOut->SetAttribute(ST->ConOut, EFI_LIGHTGREEN);
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

        ST->ConOut->OutputString(ST->ConOut, &input->UnicodeChar);
    }

    while (true)
        asm("hlt");

    return EFI_SUCCESS;
}
