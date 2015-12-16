;
;   fogOS
;   by
;   Fogus
;
;   Filename:   stage1.asm
;
;   Pupose:     This is the stage 1 loader that enables A20 and jumps to the
;               kernel.  Eventually, this will be fancy pants and do some
;		cool picture display or somesuch. 
;
;   Assemble using:
;      nasm -f elf -o stage1.o stage1.asm
;

global _start
extern k_main
_start:
jmp start2
align 4
dd 0x1badb002
dd 0
dd 0 - 0x1badb002
start2:
push ebx
push eax
call k_main
jmp $ 

