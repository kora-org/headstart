gdt_start:
    dq 0h

gdt_code:
    dw 0xffff
    dw 0h
    db 0h
    db 10011010b
    db 11001111b
    db 0h

gdt_data:
    dw 0xffff
    dw 0h
    db 0h
    db 10010010b
    db 11001111b
    db 0h

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start
