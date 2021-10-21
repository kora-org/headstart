[bits 16]
[org 0x7c00]
jmp short load_stage0
nop

OEMLabel          db "XEPTBOOT"
BytesPerSector    dw 512
SectorsPerCluster db 1
ReservedForBoot   dw 1
NumberOfFats      db 2
RootDirEntries    dw 224
LogicalSectors    dw 2880
MediumByte        db 0xF0
SectorsPerFat     dw 9
SectorsPerTrack   dw 18
Sides             dw 2
HiddenSectors     dd 0
LargeSectors      dd 0
DriveNo           dw 0
Signature         db 41
VolumeID          dd 00000000h
VolumeLabel       db "XeptoBoot01"
FileSystem        db "FAT12   "

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

print:
	mov ah, 0x0e

.print_loop:
	lodsb
	test al, al
	jz .end
	int 0x10
	jmp .print_loop

.end:
	ret

[bits 32]
start_stage1:
    call STAGE1_OFFSET
    jmp $

BOOT_DRIVE db 0

times 510 - ($-$$) db 0
dw 0xaa55
