.section .text
.global _start
.extern entry

_start:
    call entry

    cli
h:  hlt
    jmp h
