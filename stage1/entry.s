[bits 32]
[global _start]
[extern stage1_entry]
_start:
    call stage1_entry
    jmp $
