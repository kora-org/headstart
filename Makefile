CC := clang -target i686-pc-elf
LD := ld.lld
AS := nasm

CFLAGS := -nostdlib -O0 -g -Wall -Wextra
CHARDFLAGS := -nostdlib -ffreestanding -fno-stack-protector -Istage1 -Icommon
LDFLAGS :=
LDHARDFLAGS := -Ttext 0x1000 --oformat binary
ASFLAGS := -W+all

COMMON_SRC := $(wildcard common/*.c common/*/*.c)
COMMON_OBJ := $(patsubst common/%, build/common/%.o, $(COMMON_SRC:%.c=%))

STAGE1_SRC := $(filter-out $(addsuffix /%, stage1/uefi), $(wildcard stage1/*.c stage1/*/*.c stage1/*.s stage1/*/*.s))
STAGE1_OBJ := $(patsubst stage1/%, build/stage1/%.o, $(STAGE1_SRC:%.c=%))
STAGE1_OBJ += $(patsubst stage1/%, build/stage1/%.o, $(STAGE1_OBJ:%.s=%))

all: $(shell mkdir -p build/stage0 build/stage1 build/common) build/xeptoboot.bin

build/stage1.bin: $(COMMON_OBJ) $(STAGE1_OBJ)
	$(LD) $(LDFLAGS) $(LDHARDFLAGS) $^ -o $@

build/stage1/%.s.o: stage1/%.s
	$(AS) $< $(ASFLAGS) -f elf -o $@

build/stage1/%.o: stage1/%.c
	$(CC) $(CFLAGS) $(CHARDFLAGS) -c $< -o $@

build/common/%.o: common/%.c
	$(CC) $(CFLAGS) $(CHARDFLAGS) -c $< -o $@

build/stage0.bin: stage0/bootsect.s
	$(AS) $< -Istage0 -f bin -o $@

build/xeptoboot.bin: build/stage0.bin build/stage1.bin
	cat $^ > $@

run: build/xeptoboot.bin
	qemu-system-i386 -hda $< -debugcon stdio -no-reboot

clean:
	$(RM)r build
