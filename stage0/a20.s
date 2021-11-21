check_a20:
    pushf
    push ds
    push es
    push di
    push si
 
    cli
 
    xor ax, ax
    mov es, ax
 
    not ax
    mov ds, ax
 
    mov di, 0x0500
    mov si, 0x0510
 
    mov al, byte [es:di]
    push ax
 
    mov al, byte [ds:si]
    push ax
 
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xFF
 
    cmp byte [es:di], 0xFF
 
    pop ax
    mov byte [ds:si], al
 
    pop ax
    mov byte [es:di], al
 
    mov ax, 0
    je .exit
 
    mov ax, 1
 
.exit:
    pop si
    pop di
    pop es
    pop ds
    popf
 
    ret

enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
