[bits 16]
[org 0x7c00]

STAGE1_OFFSET equ 7e00h
_start:
    jmp short load_stage0
    nop

    times 87 db 0x00

load_stage0:
    mov si, .msg
    call print_e9
    mov [BOOT_DRIVE], dl

    mov bp, 7c00h
    mov sp, bp

    call load_stage1
    call enter_pmode

    jmp $

.msg: db "[stage0] XeptoBoot 0.1\n[stage0] Starting up...", 0

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
	mov ah, 0eh

.print_loop:
	lodsb
	test al, al
	jz .end
	int 10h
	jmp .print_loop

.end:
	ret

print_e9:
    mov ah, 0eh

.print_loop:
    lodsb
    test al, al
    jz .end
    out 0xe9, al
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
