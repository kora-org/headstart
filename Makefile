CC := clang -target i386-elf
LD := ld.lld
AS := nasm

CFLAGS := -O0 -g
CHARDFLAGS := -nostdlib -ffreestanding
LDFLAGS :=
LDHARDFLAGS := -T linker.ld --oformat binary
ASFLAGS := -F dwarf

STAGE1_SRC := $(wildcard stage1/*.c stage1/*/*.c stage1/*.s stage1/*/*.s)
STAGE1_OBJ := $(patsubst stage1/%, build/stage1/%.o, $(STAGE1_SRC:%.c=%))
STAGE1_OBJ += $(patsubst stage1/%, build/stage1/%.o, $(STAGE1_OBJ:%.s=%))

all: $(shell mkdir -p build/stage0 build/stage1) run

build/stage1.bin: $(STAGE1_OBJ)
	$(LD) $(LDFLAGS) $(LDHARDFLAGS) $^ -o $@

build/stage1/%.s.o: stage1/%.s
	$(AS) $< $(ASFLAGS) -f elf -o $@

build/stage1/%.o: stage1/%.c
	$(CC) $(CFLAGS) $(CHARDFLAGS) -c $< -o $@

build/stage0.bin: stage0/stage0.s
	$(AS) $< -Istage0 -f bin -o $@

build/xeptoboot.bin: build/stage0.bin build/stage1.bin
	cat $^ > $@

run: build/xeptoboot.bin
	qemu-system-i386 -fda $<

clean:
	$(RM)r build
