.global _start
.extern stage1_entry
_start:
    call stage1_entry
    jmp .loop
.loop:
    hlt
    jmp .loop
