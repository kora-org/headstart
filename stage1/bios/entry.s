.section .text
.global _start

_start:
    call entry

1:  hlt
    jmp 1b
