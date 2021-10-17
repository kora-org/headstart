[bits 16]
[org 0x7c00]
jmp short load_stage0
nop

OEMLabel              db "XEPTO   "
BytesPerSector        dw 0x0200
SectorsPerCluster     db 0x08
ReservedSectors       dw 0x0020
TotalFATs             db 0x02
MaxRootEntries        dw 0x0000
NumberOfSectors       dw 0x0000
MediaDescriptor       db 0xF8
SectorsPerFAT         dw 0x0000
SectorsPerTrack       dw 0x003D
SectorsPerHead        dw 0x0002
HiddenSectors         dd 0x00000000
TotalSectors          dd 0x00FE3B1F
BigSectorsPerFAT      dd 0x00000778
Flags                 dw 0x0000
FSVersion             dw 0x0000
RootDirectoryStart    dd 0x00000002
FSInfoSector          dw 0x0001
BackupBootSector      dw 0x0006
times 12 db 0
DriveNumber           db 0x00
ReservedByte          db 0x00
Signature             db 0x29
VolumeID              dd 0xFFFFFFFF
VolumeLabel           db "XEPTOBOOT  "
SystemID              db "FAT32   "

STAGE1_OFFSET equ 0x7e00

load_stage0:
    mov [BOOT_DRIVE], dl

    mov bp, 0x7c00
    mov sp, bp

    call load_stage1
    call enter_pmode

    jmp $

%include "disk.s"
%include "gdt.s"
%include "pmode.s"

[bits 16]
load_stage1:
    mov bx, STAGE1_OFFSET
    mov dh, 2
    mov dl, [BOOT_DRIVE]
    call disk_load
    ret

[bits 32]
start_stage1:
    call STAGE1_OFFSET
    jmp $

BOOT_DRIVE db 0

times 510 - ($-$$) db 0
dw 0xaa55
