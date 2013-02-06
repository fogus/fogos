;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; First-stage bootloader graphical test program
; Chris Giese <geezer@execpc.com>, http://www.execpc.com/~geezer
;
; This code is public domain (no copyright).
; You can do whatever you want with it.
;
; 1. Install your first-stage bootloader on a floppy disk.
;
; 2. Assemble this file with NASM:
;	nasm -f bin -o show-bmp.bin show-bmp.asm
;
; 3. Attach an uncompressed 640x480x256 .BMP file, then copy to
;    floppy disk with name and location suitable for first-stage
;    bootloader:
;
;	(DOS)	copy /b show-bmp.bin + x.bmp a:\load.bin
;
;	(Linux)	mount /dev/fd0 /mnt
;		cat show-bmp.bin x.bmp >/mnt/load.bin
;
; 3. Boot from the disk. See if the .BMP file is properly displayed.
;    (It will be upside-down.)
;
; 4. Eject the floppy disk and press a key to reboot from the hard disk.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; We need to make DOS think this is an .EXE file, because this file is >64K
; when the .BMP file is attached and DOS won't run such a large .COM file.

ORG 100h

; execution starts here for .COM file loaded from bootloader
start:
	db 4Dh, 5Ah			; EXE file signature
	jmp short com_start		; dw TOTAL_SIZE % 512

; I thought I wanted to round this value up (+1), because the previous
; value is a short JMP rather than the true modulus of the file size.
; When I round it up, however, DOS complains that the .EXE file is bad.
	;dw (TOTAL_SIZE + 511) / 512 + 1
	dw (TOTAL_SIZE + 511) / 512

	dw 0				; relocation information (none)
	dw (com_start - start) / 16	; header size in paragraphs
	dw 0				; min extra mem
	dw 0FFFFh			; max extra mem

; com_start = 120h, converted to segment value is 12h
; must subtract this value from initial segment register values, I guess...
	dw -12h				; initial SS (before fixup)
	dw stack			; initial SP
	dw 0				; checksum (none)
	dw exe_start			; initial IP
	dw -12h				; initial CS (before fixup)
	dw 0				; file offset to relocations (none)
	dw 0				; (no overlay)
	dw 0, 0				; align to 16-byte boundary

com_start:
	push dx			; undo 5Ah (pop dx) in .EXE signature
	inc bp			; undo 4Dh (dec bp) in .EXE signature
exe_start:
	mov bx,[0]		; save ds:[0] value for later PSP test
	mov ax,cs
	mov ds,ax
	mov ss,ax
	mov sp,stack

; check for DOS PSP
	cmp bx,20CDh		; "INT 20h"
	jne main
	inc byte [dos]
main:
; check if 640x480x256 .BMP file attached, at address 'end'
	mov si,bmp_error_msg
	cmp word [end + 0],4D42h ; "BM"
	jne error

	cmp byte [end + 28],8	; 256 colors (depth = 8)
	jne error

	cmp word [end + 30],0	; no RLE compression
	jne error
	cmp word [end + 30 + 2],0
	jne error

	cmp word [end + 18],640	; 640 pixels wide
	jne error
	cmp word [end + 18 + 2],0
	jne error

	cmp word [end + 22],480	; 480 pixels high
	jne error
	cmp word [end + 22 + 2],0
	je bmp_ok
error:
	call wrstr

	xor ax,ax
	or al,[dos]
	je reboot

	mov ax,4C01h		; DOS terminate
	int 21h
reboot:
	mov ah,0		; await key pressed
	int 16h

	int 19h			; re-start the boot process

bmp_ok:
; check for VESA video BIOS
	mov si,vesa_error_msg
	push ds
	pop es
	mov di,vesa_buffer
	mov ax,4F00h
	int 10h
	cmp ax,004Fh
	jne error

; get info for VESA mode 101h (640x480x256)
	mov ax,4F01h
	mov cx,0101h
	int 10h
	cmp ax,004Fh
	jne error

; compute number of granules in one 64K bank
	xor dx,dx
	mov ax,40h
	div word [vesa_buffer + 4]
	mov [gran_per_64k],ax

	xor ax,ax
	or al,[dos]
	jne no_wait
	mov si,continue_msg	; tell user to eject floppy when done
	call wrstr
	mov ah,0		; await key pressed
	int 16h
no_wait:

; set video mode 101h
	mov ax,4F02h
	mov bx,0101h
	int 10h
	cmp ax,004Fh
	jne error

; set palette
	mov cx,256
	lea si,[end + 54]

	mov dx,3C8h		; start with palette index #0
	xor al,al
	out dx,al
	inc dx
set_pal:
	mov al,[si + 2]		; red
	shr al,1
	shr al,1
	out dx,al

	mov al,[si + 1]		; green
	shr al,1
	shr al,1
	out dx,al

	mov al,[si + 0]		; blue
	shr al,1
	shr al,1
	out dx,al

	add si,4		; skip unused 4th byte
	loop set_pal

; create pointers: DS:SI->src bitmap data (already done),
; ES:DI->dst framebuffer
	mov di,0A000h
	mov es,di
	xor di,di

; zero "granule" (bank) number
	xor dx,dx
	push ds

; 640 * 480 = 307200 bytes / 64K = 4.68 ~ 5
		mov cx,5
outer_loop:
		push cx

; 64K / 16 = 4096
			mov cx,4096

; ...copy 16 bytes to framebuffer
inner_loop:
			push si
			push cx
				mov cx,16
				rep movsb
			pop cx
			pop si

; ...advance DS by 1, instead of SI by 16
			mov ax,ds
			inc ax
			mov ds,ax
			loop inner_loop

; DI "rolled over" to 0 again; no need to re-load it
		pop cx

; change bank for window A
		add dx,[ss:gran_per_64k]
		mov ax,4F05h
		xor bx,bx

; oops, the BIOS for my Cirrus 5422-based video board clobbers DX
		push dx
			int 10h
		pop dx
		loop outer_loop
	pop ds

; await key pressed
	mov ah,0
	int 16h

; go back to text mode
	mov ax,3
	int 10h

	xor ax,ax
	or al,[dos]
	je reboot2

	mov ax,4C01h		; DOS terminate
	int 21h
reboot2:
	int 19h			; re-start the boot process

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; name:			wrstr
; action:		writes ASCIZ string to text screen
; in:			0-terminated string at DS:SI
; out:			(nothing)
; modifies:		(nothing)
; minimum CPU:		8088
; notes:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

wrstr:	push ax
	push bx
	push si
		mov ah,0Eh	; INT 10h: teletype output
		xor bx,bx	; video page 0
		jmp wrstr2
wrstr1:		int 10h
wrstr2:		lodsb
		or al,al
		jne wrstr1
	pop si
	pop bx
	pop ax
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

dos:
%ifdef DOS
	db 1	; assume it's always DOS
%else
	db 0	; test for PSP to see if DOS is present or not
%endif

bmp_error_msg:
	db "Error in .BMP file attached to this bootsector.", 13, 10
	db "It must be a 256-color uncompressed 640x480 .BMP file"
	db 13, 10, 0

vesa_error_msg:
	db "No VESA video BIOS, or error setting VESA mode 101h (640x480x256)"
	db 13, 10, 0

continue_msg:
	db "After the picture has been displayed,", 13, 10
	db "eject the floppy and press a key to reboot.", 13, 10
	db "Press a key...", 0

gran_per_64k:
	dw 0

vesa_buffer:
	times 512 db 0

	times 256 dw 0
stack:

; Segment rollover (across 64K boundary) is most likely to occur
; while reading the 307200-byte raster data in the .BMP file, not
; while reading the 54-byte .BMP header or the 1024-byte palette.
;
; Aligning the raster data to a paragraph (16-byte) boundary will
; prevent rollover.
;
; Load offset of this file:	100h
; Size of this file:		X bytes
; Size of .BMP header:		54 bytes
; Size of .BMP palette:		1024 bytes
;
; We want (100h + X + 54 + 1024) to be a multiple of 16, or
;	(1334 + X) % 16 = 0
; from http://www.cs.uiowa.edu/~jones/bcd/decimal.html
; "...the modulus operator is distributive in an interesting sense:"
;	((1334 % 16) + (X % 16)) % 16 = 0
;	(6 + (X % 16)) = 0,16,32,48...
;	(X % 16) = 10

	align 16
	times 10 nop

; .BMP file is attached here
end:

STUB_SIZE	equ	(end - start)
BMP_SIZE	equ	(54 + 1024 + 640 * 480)
TOTAL_SIZE	equ	(STUB_SIZE + BMP_SIZE)
