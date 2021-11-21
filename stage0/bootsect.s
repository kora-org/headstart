[bits 16]
[org 0x7c00]

STAGE1_OFFSET equ 0x1000

boot_stage0:
    mov [BOOT_DRIVE], dl
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x8000

    call check_a20
    cmp ax, 0
    jne .a20_success
    call enable_a20
    call load_stage1
    call switch_to_pm
    jmp $

.a20_success:

%include "a20.s"
%include "print.s"
%include "print_hex.s"
%include "disk.s"
%include "gdt.s"
%include "switch_pm.s"

[bits 16]
load_stage1:
    mov bx, STAGE1_OFFSET
    mov dh, 16
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
