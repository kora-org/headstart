#pragma once
#include <efi.h>
#include <efilib.h>
#include <uefi_common.h>
#include <elf.h>

EFI_STATUS load_elf(CHAR16* path);
