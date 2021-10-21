#include <efi.h>
#include <efilib.h>
#include <string.h>
#include <elf.h>
#include <elf_loader.h>

static EFI_FILE* load_file(EFI_FILE* directory, CHAR16* path, EFI_HANDLE image_handle, EFI_SYSTEM_TABLE* system_table) {
    EFI_FILE* loaded_file;

    EFI_LOADED_IMAGE_PROTOCOL* loaded_image;
    system_table->BootServices->HandleProtocol(image_handle, &gEfiLoadedImageProtocolGuid, (void**)&loaded_image);

    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL* filesystem;
    system_table->BootServices->HandleProtocol(loaded_image->DeviceHandle, &gEfiSimpleFileSystemProtocolGuid, (void**)&filesystem);

    if (directory == NULL) {
        filesystem->OpenVolume(filesystem, &directory);
    }

    EFI_STATUS s = directory->Open(directory, &loaded_file, path, EFI_FILE_MODE_READ, EFI_FILE_READ_ONLY);
    if (s != EFI_SUCCESS) {
        return NULL;
    }

    return loaded_file;
}

EFI_STATUS load_elf(CHAR16* path) {
    EFI_FILE* kernel = load_file(NULL, path, ImageHandle, ST);
    if (kernel == NULL) {
        ST->ConOut->OutputString(ST->ConOut, L"[panic] Could not load kernel\n\r");
    }

    Elf64_Ehdr header;
    {
        UINTN file_info_size;
        EFI_FILE_INFO* file_info;
        kernel->GetInfo(kernel, &gEfiFileInfoGuid, &file_info_size, NULL);
        BS->AllocatePool(EfiLoaderData, file_info_size, (void**)&file_info);
        kernel->GetInfo(kernel, &gEfiFileInfoGuid, &file_info_size, (void**)&file_info);
        UINTN size = sizeof(header);
        kernel->Read(kernel, &size, &header);
    }

    if (memcmp(&header.e_ident[EI_MAG0], ELFMAG, SELFMAG) != 0 ||
        header.e_ident[EI_CLASS] != ELFCLASS64 ||
        header.e_ident[EI_DATA] != ELFDATA2LSB ||
        header.e_type != ET_EXEC ||
        header.e_machine != EM_X86_64 ||
        header.e_version != EV_CURRENT) {
        ST->ConOut->OutputString(ST->ConOut, L"[panic] Kernel header is invalid\n\r");
    }

    Elf64_Phdr* phdrs;
    {
        kernel->SetPosition(kernel, header.e_phoff);
        UINTN size = header.e_phnum * header.e_phentsize;
        BS->AllocatePool(EfiLoaderData, size, (void**)&phdrs);
        kernel->Read(kernel, &size, phdrs);
    }

    for (Elf64_Phdr* phdr = phdrs;
        (char*)phdr < (char*)phdrs + header.e_phnum * header.e_phentsize;
        phdr = (Elf64_Phdr*)((char*)phdr + header.e_phentsize)) {
        switch (phdr->p_type) {
            case PT_LOAD: {
                int pages = (phdr->p_memsz + 0x1000 - 1) / 0x1000;
                Elf64_Addr segment = phdr->p_paddr;
                BS->AllocatePages(AllocateAddress, EfiLoaderData, pages, &segment);

                kernel->SetPosition(kernel, phdr->p_offset);
                UINTN size = phdr->p_filesz;
                kernel->Read(kernel, &size, (void*)segment);
                break;
            }
        }
    }

    int (*kernel_start)() = ((__attribute__((sysv_abi)) int (*)() ) header.e_entry);
    if (kernel_start())
        ST->ConOut->OutputString(ST->ConOut, L"Kernel successfully started\n\r");
        return EFI_SUCCESS;
}
