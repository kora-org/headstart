disk_load:
    pusha
    push dx

    mov ah, 02h
    mov al, dh
    mov cl, 02h
    mov ch, 00h
    mov dh, 00h

    int 13h
    jc disk_error

    pop dx
    cmp al, dh
    jne sectors_error
    popa
    ret

disk_error:
    mov si, .msg
    call print
    jmp disk_loop

.msg: db "[panic] Disk error. System halted", 0

sectors_error:
    mov si, .msg
    call print
    jmp disk_loop

.msg: db "[panic] Sector error. System halted", 0

disk_loop:
    hlt
    jmp $
