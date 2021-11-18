ENTRY(_start)

SECTIONS {
    . = 0x500;
    _stack_start = .;
    . = 0x1000;
    _stack_end = .;

    .text : {
        *(.text)
        *(.data)
        *(.rodata)
        *(.bss)
        *(COMMON)
    }
    /DISCARD/ : {
        *(.eh_frame)
    }
}
