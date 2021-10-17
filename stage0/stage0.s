[bits 16]
[org 0x7c00]

STAGE1_OFFSET equ 1000h

mov [BOOT_DRIVE], dl

mov bp, 9000h
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
load_32bit:
    call STAGE1_OFFSET
    jmp $

BOOT_DRIVE db 0

times 510 - ($-$$) db 0

dw 0xaa55
