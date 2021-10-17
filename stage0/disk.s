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
    jmp disk_loop

sectors_error:
    jmp disk_loop

disk_loop:
    jmp $
