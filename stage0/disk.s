disk_load:
    cli

    cmp dl, 0x80
    jc floppy_detected_error

    mov ah, 0x42
    mov si, .dap
    int 0x13
    jc disk_error

    ret

.dap:
    db 0x10, 0
    dw 1
    dd STAGE1_OFFSET
    dq 1

floppy_detected_error:
    mov bx, FLOPPY_DETECTED_ERROR_MSG
    call print
    mov dh, ah
    call print_hex
    jmp disk_loop

disk_error:
    mov bx, DISK_ERROR_MSG
    call print
    mov dh, ah
    call print_hex
    jmp disk_loop

disk_loop:
    cli
    .halt: hlt
    jmp .halt

FLOPPY_DETECTED_ERROR_MSG: db "[panic] Floppy disks isn't supported. Error code: ", 0
DISK_ERROR_MSG: db "[panic] Disk read error. Error code: ", 0
