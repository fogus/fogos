;
;   Unknown OS
;   by
;   Fogus
;
;   File:   boot.asm
;
;   Purpose:
;       Provides the x86 boot code.  Intended to be assembled
;       by NASM.
;
;       The boot code is intended to fall within 512 bytes and start at sector
;       zero.  In addition, the code will be checked for overflow by NASM in
;       order to prevent needless bug tracking on a code size >512 bytes.
;

org     0h

ID                  db  "fogOS "
bytes_per_sector    dw  0200h       ; 512 bytes
sectors_per_sector  db  01h         
leading_sectors     dw  0001h       
num_fat             db  02h
root_entry_max      dw  00E0h       
total_sectors       dw  0B40h       ; 2880
media_type          db  0F0h
sectors_per_fat     dw  0009h
sectors_per_track   dw  0012h       ; 18
num_heads           dw  0002h
hidden_sectors      dd  00000000h
total_sectors2      dd  00000000h
boot_disk           db  00h         ; 0x0=A  0x80=C
reserved            db  00h
boot_sig            db  29h         ; 41
volume_id           dd  69696969h   
volume_label        db  ID
fat_id              db  "FAT12 "

jmp start

start: 

cli                 ; Disable interrupts 
mov ax, 07C0h       ; Load code segment 
mov ds, ax          ; Store in segment register 
mov es, ax          ; Store in segment register

; Setup the stack
mov ax, 9000h       ; Load stack segment 
mov ss, ax          ; Store in segment register 
mov sp, 0FFFFh      ; Start the stack at the end of the segment 
sti                 ; Re-enable interrupts 




;###################################################### 
; Message Display Procedure 
;###################################################### 
print: 
lodsb               ;Load a byte from DS:SI 
or al, al           ;Check to see if it is 0 (end of string) 
jz print_end        ;Exit if 0 
mov ah, 0Eh         ;BIOS function to output character and advance the cursor 
mov bh, 00h         ;Video Page Number 
int 10h             ;Call BIOS video interrupts 
jmp print           ;Get next character 
print_end: 
ret 
;######################################################

times (510 + $$-$) nop
db 55h, 0AAh

