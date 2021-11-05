#include <efi.h>
#include <efilib.h>
#include <string.h>
#include <elf.h>
#include <elf_loader.h>

typedef struct {
    void (*print)(CHAR16 *);
} xeptoboot_hdr;

static EFI_FILE *load_file(EFI_FILE *directory, CHAR16 *path) {
    EFI_FILE *loaded_file;

    EFI_LOADED_IMAGE *loaded_image;
    EFI_GUID loaded_image_guid = EFI_LOADED_IMAGE_PROTOCOL_GUID;
    BS->HandleProtocol(IM, &loaded_image_guid, (void **)&loaded_image);

    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *filesystem;
    EFI_GUID fs_guid = EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID;
    BS->HandleProtocol(loaded_image->DeviceHandle, &fs_guid, (void **)&filesystem);

    if (directory == NULL) {
        filesystem->OpenVolume(filesystem, &directory);
    }

    EFI_STATUS s = directory->Open(directory, &loaded_file, path, EFI_FILE_MODE_READ, EFI_FILE_READ_ONLY | EFI_FILE_HIDDEN | EFI_FILE_SYSTEM);
    if (s != EFI_SUCCESS) {
        return NULL;
    }

    return loaded_file;
}

static void xeptoboot_print(CHAR16 *str) {
    ST->ConOut->OutputString(ST->ConOut, str);
}

EFI_STATUS load_elf(CHAR16 *path) {
    EFI_FILE *kernel = load_file(NULL, path);
    if (kernel == NULL) {
        ST->ConOut->OutputString(ST->ConOut, L"Could not load kernel.\r\n");
        return EFI_LOAD_ERROR;
    }

    Elf64_Ehdr header;
    {
        UINTN file_info_size;
        EFI_FILE_INFO *file_info;
        EFI_GUID file_info_guid = EFI_FILE_INFO_ID;
        kernel->GetInfo(kernel, &file_info_guid, &file_info_size, NULL);
        BS->AllocatePool(EfiBootServicesData, file_info_size, (void **)&file_info);
        kernel->GetInfo(kernel, &file_info_guid, &file_info_size, (void **)&file_info);
        UINTN size = sizeof(header);
        kernel->Read(kernel, &size, &header);
    }

    if (memcmp(&header.e_ident[EI_MAG0], ELFMAG, SELFMAG) != 0 &&
        header.e_ident[EI_CLASS] != ELFCLASS64 &&
        header.e_ident[EI_DATA] != ELFDATA2LSB &&
        header.e_type != ET_EXEC &&
        header.e_machine != EM_X86_64 &&
        header.e_version != EV_CURRENT) {
        ST->ConOut->OutputString(ST->ConOut, L"Kernel header is invalid.\r\n");
        return EFI_LOAD_ERROR;
    }

    Elf64_Phdr *phdrs;
    {
        kernel->SetPosition(kernel, header.e_phoff);
        UINTN size = header.e_phnum * header.e_phentsize;
        BS->AllocatePool(EfiBootServicesData, size, (void **)&phdrs);
        kernel->Read(kernel, &size, phdrs);
    }

    for (Elf64_Phdr *phdr = phdrs;
        (char *)phdr < (char *)phdrs + header.e_phnum * header.e_phentsize;
        phdr = (Elf64_Phdr *)((char *)phdr + header.e_phentsize)) {
        switch (phdr->p_type) {
            case PT_LOAD: {
                int pages = (phdr->p_memsz + 0x1000 - 1) / 0x1000;
                Elf64_Addr segment = phdr->p_paddr;
                BS->AllocatePages(AllocateAddress, EfiBootServicesData, pages, &segment);

                kernel->SetPosition(kernel, phdr->p_offset);
                UINTN size = phdr->p_filesz;
                kernel->Read(kernel, &size, (void *)segment);
                break;
            }
        }
    }

    /*EFI_MEMORY_DESCRIPTOR *map;
    UINTN map_size, map_key;
    UINTN descriptor_size;
    UINT32 descriptor_version;
    {
        BS->GetMemoryMap(&map_size, map, &map_key, &descriptor_size, &descriptor_version);
        BS->AllocatePool(EfiBootServicesData, map_size, (void **)&map);
        BS->GetMemoryMap(&map_size, map, &map_key, &descriptor_size, &descriptor_version);
    }

    BS->ExitBootServices(IM, map_key);*/
    void (*kernel_start)(xeptoboot_hdr *) = ((__attribute__((sysv_abi))void(*)(xeptoboot_hdr *))header.e_entry);

    xeptoboot_hdr *xeptoboot;
    BS->AllocatePool(EfiBootServicesData, sizeof(xeptoboot), (void **)&xeptoboot);
    xeptoboot->print = xeptoboot_print;

    kernel_start(xeptoboot);
    return EFI_SUCCESS;
}
