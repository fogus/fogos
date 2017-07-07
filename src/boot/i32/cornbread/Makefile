# This makefile is geared for use with cygwin

all : loader.bin load.exe

install : loader.bin load
	dd bs=1 if=loader.bin skip=0  count=3   of=f0
	dd bs=1 if=loader.bin skip=36 count=476 of=f0 seek=36

# this target for testing purposes only
test : loader.asm
	nasm -f bin -dDOS=1 -o loader.com loader.asm
# the leading hyphen should supress the error if NDISASM is not installed
	-ndisasm -o 0x100 loader.com > loader.lst

clean :
	rm -f *.bin *.exe *.com *.obj *.lst

loader.bin : loader.asm
	nasm -f bin -o loader.bin loader.asm
# the leading hyphen should supress the error if NDISASM is not installed
	-ndisasm -o 0x100 loader.bin > loader.lst

load : load.exe
	cp -f load.exe /cygdrive/a

load.exe : stage2.asm fogos.bmp
	nasm -f bin -o stage2.bin stage2.asm
# define DOS to disable run-time check for DOS (stage2 will assume
# DOS is present, and use INT 21h AH=4Ch to exit). This lets you
# put TEST.EXE on a floppy, and load it from DOS using loader.COM
# This is for testing purposes only!
#	nasm -f bin -dDOS=1 -o stage2.bin stage2.asm
	cat stage2.bin fogos.bmp > load.exe
