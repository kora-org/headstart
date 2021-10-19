#include <efi.h>
#include <efilib.h>
#include <keyboard.h>
#include <uefi_common.h>

EFI_STATUS get_keystroke(EFI_INPUT_KEY *key) {
    return ST->ConIn->ReadKeyStroke(ST->ConIn, key);
}
