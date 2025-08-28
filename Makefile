BIN_HOME   := bin
SRC_HOME   := src
INCLUDE_HOME := $(SRC_HOME)/include

CC   := /opt/homebrew/bin/x86_64-elf-gcc
AS   := nasm
LD   := /opt/homebrew/bin/x86_64-elf-ld

CFLAGS := -m32 -c -O2 -Wall -W -nostdinc -fno-builtin -I$(INCLUDE_HOME)
ASFLAGS := -f elf32
LDFLAGS := -m elf_i386 --oformat=elf32-i386 -Ttext 100000 -nostdlib

KERNEL_SRC = \
	$(SRC_HOME)/kernel/kernel.c \
	$(SRC_HOME)/kernel/kprint.c \
	$(SRC_HOME)/kernel/kvideo.c \
	$(SRC_HOME)/kernel/kmemory.c \
	$(SRC_HOME)/kernel/kio.c \
	$(SRC_HOME)/kernel/kcrypt.c \
	$(SRC_HOME)/lib/string.c \
	$(SRC_HOME)/hal/x86/HAL_interrupts.c

OBJS = \
	$(BIN_HOME)/stage1.o \
	$(BIN_HOME)/kernel.o \
	$(BIN_HOME)/kprint.o \
	$(BIN_HOME)/kvideo.o \
	$(BIN_HOME)/kmemory.o \
	$(BIN_HOME)/kio.o \
	$(BIN_HOME)/kcrypt.o \
	$(BIN_HOME)/string.o \
	$(BIN_HOME)/HAL_interrupts.o

TARGET = $(BIN_HOME)/fogos.x

.PHONY: all clean

all: x86

x86: clean $(TARGET)

$(BIN_HOME)/stage1.o: $(SRC_HOME)/boot/i32/stage1.asm
	mkdir -p $(BIN_HOME)
	$(AS) $(ASFLAGS) -o $@ $<

$(BIN_HOME)/%.o: $(SRC_HOME)/kernel/%.c
	mkdir -p $(BIN_HOME)
	$(CC) $(CFLAGS) -o $@ $<

$(BIN_HOME)/%.o: $(SRC_HOME)/lib/%.c
	mkdir -p $(BIN_HOME)
	$(CC) $(CFLAGS) -o $@ $<

$(BIN_HOME)/%.o: $(SRC_HOME)/hal/x86/%.c
	mkdir -p $(BIN_HOME)
	$(CC) $(CFLAGS) -o $@ $<

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -rf $(BIN_HOME)/*

QEMU := /opt/homebrew/bin/qemu-system-x86_64
QEMUFLAGS := -m 256M -kernel $(TARGET)

.PHONY: run
run: $(TARGET)
	$(QEMU) $(QEMUFLAGS)
