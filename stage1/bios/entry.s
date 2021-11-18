.section .text
.global _start
.extern entry

_start:
    call entry
    jmp .loop

.loop:
    hlt
    jmp .loop
