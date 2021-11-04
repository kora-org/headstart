[org 0x7c00]
STAGE1_OFFSET equ 0x1000

    mov [BOOT_DRIVE], dl
    mov bp, 0x9000
    mov sp, bp

    call load_stage1
    call switch_to_pm
    jmp $

%include "print.s"
%include "print_hex.s"
%include "disk.s"
%include "gdt.s"
%include "switch_pm.s"

[bits 16]
load_stage1:
    mov bx, STAGE1_OFFSET ; Read from disk and store in 0x1000
    mov dh, 16 ; Our future kernel will be larger, make this big
    mov dl, [BOOT_DRIVE]
    call disk_load
    ret

[bits 32]
BEGIN_PM:
    call STAGE1_OFFSET
    jmp $

BOOT_DRIVE db 0

times 510 - ($-$$) db 0
dw 0xaa55
