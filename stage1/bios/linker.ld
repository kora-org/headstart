##OUTPUT_FORMAT(binary)
ENTRY(_start)

SECTIONS {
    . = 0x1000;
    .text : {
        *(.text)
        *(.data)
        *(.rodata)
        *(.bss)
    }
}
