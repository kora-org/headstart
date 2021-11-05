disk_load:
    cli
    pusha
    push dx

    mov ah, 0x02
    mov al, dh
    mov cl, 0x02
    mov ch, 0x00
    mov dh, 0x00

    cmp dl, 0x80
    jc floppy_detected_error

    mov ah, 0x41
    mov bx, 0x55aa

    int 0x13
    jc disk_error

    pop dx
    cmp al, dh
    jne sectors_error

    popa
    ret

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

sectors_error:
    mov bx, SECTORS_ERROR_MSG
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
SECTORS_ERROR_MSG: db "[panic] Incorrect number of sectors read. Error code: ", 0
