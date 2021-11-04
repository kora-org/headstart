disk_load:
    pusha
    push dx

    mov ah, 0x02
    mov al, dh
    mov cl, 0x02
    mov ch, 0x00
    mov dh, 0x80

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
    mov bx, FLOPPY_DETECTED_ERROR
    call print
    jmp disk_loop

disk_error:
    mov bx, DISK_ERROR
    call print
    mov dh, ah
    call print_hex
    jmp disk_loop

sectors_error:
    mov bx, SECTORS_ERROR
    call print
    jmp disk_loop

disk_loop:
    jmp $

FLOPPY_DETECTED_ERROR: db "[panic] XeptoBoot isn't designed for floppy disks. Aborting.", 0
DISK_ERROR: db "[panic] Disk read error. Code: ", 0
SECTORS_ERROR: db "[panic] Incorrect number of sectors read.", 0
