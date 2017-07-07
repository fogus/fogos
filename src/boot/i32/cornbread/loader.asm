;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; First-stage bootloader for FAT12 (DOS/Win) floppy
;
; BUILD:
;	nasm -f bin -o fat12.bin fat12.asm
;
; DOS INSTALL (do NOT use RAWRITE):
;	partcopy fat12.bin  0   3 -f0
;	partcopy fat12.bin 24 1DC -f0 24
;
; UNIX INSTALL:
;	dd bs=1 if=fat12.bin skip=0  count=3   of=/dev/fd0
;	dd bs=1 if=fat12.bin skip=36 count=476 of=/dev/fd0 seek=36
;
;	http://cs.arizona.edu/people/bridges/oses.html
;	http://l4ka.org
;	http://www.washingdishes.freeuk.com/links.html
;	http://my.execpc.com/~geezer/osd/index.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; The second stage loader must be in 8.3 FAT12 format.
; Also, the LHS and RHS are padded to the right.
%define	SS_NAME	"STAGE2  BIN"		; 2nd stage file name
SS_ADR	EQU	10000h			; where to load 2nd stage
SS_ORG	EQU	100h			; 2nd stage ORG value

; "No user-serviceable parts beyond this point" :)
; Actually, you can modify it if you want.

; first-stage address				offset	linear
%define 	FS_ORG	100h			; 100h	7C00h

; 512-byte stack. Put this ABOVE the code in memory, so this code
; can also be built as a .COM file (for testing purposes only!)
ADR_STACK	equ	(FS_ORG + 400h)		; 500h	8000h

; one-sector directory buffer. I assume FAT sectors are no larger than 4K
ADR_DIRBUF	equ	ADR_STACK		; 500h	8000h

; two-sector FAT buffer -- two sectors because FAT12
; entries are 12 bits and may straddle a sector boundary
ADR_FATBUF	equ	(ADR_DIRBUF + 1000h)	; 1500h	9000h

; start of unused memory:			  3500h	B000h

; use byte-offset addressing from BP for smaller code
%define	VAR(x)	((x) - start) + bp

; bootsector loaded at physical address 07C00h, but address 100h
; will work if we load IP and segment registers properly.
; This is also the ORG address of a DOS .COM file
	ORG FS_ORG
start:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VARIABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; (1 byte) drive we booted from; 0=A, 80h=C
boot_drive		EQU (start - 1)

; (2 bytes) number of 16-byte paragraphs per sector
para_per_sector		EQU (boot_drive - 2)

; (2 bytes) number of 32-byte FAT directory entries per sector
dir_ents_per_sector	EQU (para_per_sector - 2)

; (2 bytes) sector where the actual disk data starts
; This is relative to partition start, so we need only 16 bits
data_start		EQU (dir_ents_per_sector - 2)

; (2 bytes) number of 16-byte paragraphs per cluster
para_per_cluster	EQU (data_start - 2)

	jmp short skip_bpb
	nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MINIMAL BIOS PARAMETER BLOCK (BPB)
;
; 'Minimal' means just enough of a BPB so DOS/Windows:
; - recognizes this disk as a FAT12 floppy,
; - doesn't complain when you try to access the disk,
; - doesn't insist on a full format if you say "FORMAT /Q A:"
;
; Installation will use the BPB already present on your floppy disk.
; The values shown here work only with 1.44 meg disks (CHS=80:2:18)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

oem_id:			; offset 03h (03) - not used by this code
	db "GEEZER", 0, 0
bytes_per_sector:	; offset 0Bh (11)
	dw 512
sectors_per_cluster:	; offset 0Dh (13)
	db 1
fat_start:
num_reserved_sectors:	; offset 0Eh (14)
	dw 1
num_fats:		; offset 10h (16)
	db 2
num_root_dir_ents:	; offset 11h (17)
	dw 224
total_sectors:		; offset 13h (19) - not used by this code
	dw 18 * 2 * 80
media_id:		; offset 15h (21) - not used by this code
	db 0F0h
sectors_per_fat:	; offset 16h (22)
	dw 9
sectors_per_track:	; offset 18h (24)
	dw 18
heads:			; offset 1Ah (26)
	dw 2
hidden_sectors:		; offset 1Ch (28)
	dd 0
total_sectors_large:	; offset 20h (32) - not used by this code
	dd 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

skip_bpb:
; put CPU into a known state
%ifdef DOS
	mov dl,0	; A: drive
%else
	jmp ((7C00h - FS_ORG) / 16):fix_cs
fix_cs:
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov sp,ADR_STACK
%endif
	mov bp,start
	mov [VAR(boot_drive)],dl
	cld

; calculate some values that we need:
; 16-byte paragraphs per sector
	mov ax,[VAR(bytes_per_sector)]
	mov cl,4
	shr ax,cl
	mov [VAR(para_per_sector)],ax

; 16-byte paragraphs per cluster
	xor dh,dh
	mov dl,[VAR(sectors_per_cluster)]
	mul dx
	mov [VAR(para_per_cluster)],ax

; 32-byte FAT directory entries per sector
	mov ax,[VAR(bytes_per_sector)]
	mov bx,32 ; bytes/dirent
	xor dx,dx
	div bx
	mov [VAR(dir_ents_per_sector)],ax

; number of sectors used for root directory (store in CX)
	mov ax,[VAR(num_root_dir_ents)]
	mul bx
	div word [VAR(bytes_per_sector)]
	mov cx,ax

; first sector of root directory
	xor ah,ah
	mov al,[VAR(num_fats)]
	mul word [VAR(sectors_per_fat)]
	add ax,[VAR(num_reserved_sectors)]

; first sector of disk data area:
	mov si,ax
	add si,cx
	mov [VAR(data_start)],si

; scan root directory for file. We don't bother to check for deleted
; entries or 'virgin' entries (first byte = 0) that mark end of directory
	mov bx,ADR_DIRBUF
next_sect:
	push cx
		mov cx,1
		call read_sectors_chs
	pop cx
	jc disk_error
	mov si,bx
	push cx
		mov cx,[VAR(dir_ents_per_sector)]
next_ent:
		mov di,ss_name
		push si
		push cx
			mov cx,11 ; 8.3 FAT filename
			rep cmpsb
		pop cx
		pop si
		je found_it
		add si,32	; bytes/dirent
		loop next_ent
	pop cx
	add ax,byte 1	; next sector
	adc dx,byte 0
	loop next_sect
	mov al,'F'	; file not found; display blinking 'F'

; 'hide' the next 2-byte instruction by converting it to CMP AX,NNNN
; I learned this trick from Microsoft's Color Computer BASIC :)
	db 3Dh
disk_error:
	mov al,'R'	; disk read error; display blinking 'R'
error:
	mov ah,9Fh	; blinking blue-on-white attribute
	mov bx,0B800h	; xxx - 0B800h assumes color emulation...
	mov es,bx	; ...should still be able to hear the beep
	mov [es:0],ax

	mov ax,0E07h	; *** BEEEP ***
	int 10h
exit:
%ifdef DOS
	mov ax,4C01h
	int 21h
%else
	mov ah,0	; await key pressed
	int 16h

	int 19h		; re-start the boot process
%endif

found_it:
; leave the old CX value on the stack to save a byte or two
; Get conventional memory size (Kbytes) in AX
		int 12h

; subtract load address
%ifdef DOS
		mov dx,ds
		add dx,((SS_ADR - 7C00h) / 16)
		mov cl,6
		shr dx,cl
		sub ax,dx
%else
		sub ax,(SS_ADR / 1024)
%endif

; convert from K to bytes
		mov dx,1024
		mul dx

; 32-bit file size (4 bytes) is at [si + 28]
; If second stage file is too big...
		sub ax,[si + 28]
		sbb dx,[si + 30]

; ...display a blinking 'M'
		mov al,'M'
		jc error

; get starting cluster of file
		mov si,[si + 26]

; set load address DI:BX
		xor bx,bx
%ifdef DOS
		mov di,ds
		add di,(SS_ADR / 16)
%else
		mov di,(SS_ADR / 16)
%endif
		xor ch,ch
		mov cl,[VAR(sectors_per_cluster)]
next_cluster:
; convert 16-bit cluster value (in SI) to 32-bit LBA sector value (in DX:AX)
; and get next cluster in SI
		call walk_fat
		jc disk_error

; xxx - this will always load an entire cluster (e.g. 64 sectors),
; even if the file is shorter than this
		mov es,di
		call read_sectors_chs
		jc disk_error
		add di,[VAR(para_per_cluster)]

; 0FF6h: reserved	0FF7h: bad cluster
; 0FF8h-0FFEh: reserved	0FFFh: end of cluster chain
		cmp si,0FF6h
		jb next_cluster

; turn off floppy motor
		mov dx,3F2h
		mov al,0
		out dx,al

; jump to second stage loaded at SS_ADR and ORGed to address SS_ORG
%ifdef DOS
; build or copy a PSP for the second stage? nah, too much work...
		mov ax,ds
		add ax,((SS_ADR - SS_ORG) / 16)
%else
		mov ax,((SS_ADR - SS_ORG) / 16)
%endif
		mov ds,ax
		mov es,ax

; we leave SS:SP as they were
; Here is the actual far 'jump' to the second stage (RETF, actually)
		push ax
		mov bx,SS_ORG
		push bx
		retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; name:			read_sectors_chs
; action:		reads one or more disk sectors using INT 13h AH=02h
; in:			DX:AX=LBA number of sector to read (relative to
;			start of partition), CX=sector count, ES:BX -> buffer
; out (disk error):	CY=1
; out (success):	CY=0
; modifies:		(nothing)
; minimum CPU:		8088
; notes:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_sectors_chs:
	push es
	push di
	push dx
	push cx
	push ax

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[VAR(hidden_sectors + 0)]
		adc dx,[VAR(hidden_sectors + 2)]
		inc cx
		jmp short rsc_3
rsc_1:
		push dx
		push cx
		push ax

; DX:AX=LBA sector number
; divide by number of sectors per track to get sector number
; Use 32:16 DIV instead of 64:32 DIV for 8088 compatability
; Use two-step 32:16 divide to avoid overflow
			mov cx,ax
			mov ax,dx
			xor dx,dx
			div word [VAR(sectors_per_track)]
			xchg cx,ax
			div word [VAR(sectors_per_track)]
			xchg cx,dx

; DX:AX=quotient, CX=remainder=sector (S) - 1
; divide quotient by number of heads
			mov di,ax
			mov ax,dx
			xor dx,dx
			div word [VAR(heads)]
			xchg di,ax
			div word [VAR(heads)]
			xchg di,dx

; DX:AX=quotient=cylinder (C), DI=remainder=head (H)
; error if cylinder >=1024
			or dx,dx	; DX != 0; so cyl >= 65536
			stc
			jne rsc_2
			cmp ah,4	; AH >= 4; so cyl >= 1024
			cmc
			jb rsc_2

; move variables into registers for INT 13h AH=02h
			mov dx,di
			mov dh,dl	; DH=head
			inc cx		; CL5:0=sector
			mov ch,al	; CH=cylinder 7:0
			shl cl,1
			shl cl,1
			shr ah,1
			rcr cl,1
			shr ah,1
			rcr cl,1	; CL7:6=cylinder 9:8
			mov dl,[VAR(boot_drive)] ; DL=drive

; we call INT 13h AH=02h once for each sector. Multi-sector reads
; may fail if we cross a track or 64K boundary
			mov ax,0201h	; AH=02h, AL=num_sectors
			int 13h
			jnc rsc_2
; reset drive
			xor ax,ax
			int 13h
			jc rsc_2
; try read again
			mov ax,0201h
			int 13h
rsc_2:
		pop ax
		pop cx
		pop dx
		jc rsc_4

; increment segment part of address and LBA sector number, and loop
		mov di,es
		add di,[VAR(para_per_sector)]
		mov es,di
		inc ax
		jne rsc_3
		inc dx
rsc_3:
		loop rsc_1
rsc_4:
	pop ax
	pop cx
	pop dx
	pop di
	pop es
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; name:			walk_fat
; action:		converts cluster number to sector number and
;			finds next cluster in chain
; in:			SI = cluster
; out (disk error):	CY=1
; out (success):	CY=0, SI = next cluster, DX:AX = sector number
; modifies:		AX, DX, SI
; minimum CPU:		8088
; notes:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

walk_fat:
	push es
	push di
	push cx
	push bx

; cluster 2 is the first data cluster
		lea ax,[si - 2]

; convert from clusters to sectors
		mov dh,0
		mov dl,[VAR(sectors_per_cluster)]
		mul dx
		add ax,[VAR(data_start)]
		adc dx,byte 0

; DX:AX is return value: save it
		push dx
		push ax

; prepare to load FAT
%ifdef DOS
			mov ax,ds
			add ax,(ADR_FATBUF / 16)
%else
			mov ax,(ADR_FATBUF / 16)
%endif
			mov es,ax
			xor bx,bx

; FAT12 entries are 12 bits, bytes are 8 bits. Ratio is 3 / 2,
; so multiply cluster by 3 now, and divide by 2 later.
			xor dx,dx
			mov ax,si
			shl ax,1
			rcl dx,1
			add ax,si
			adc dx,byte 0

; DX:AX b0	=use high or low 12 bits of 16-bit value read from FAT
; DX:AX b9:1	=byte offset into FAT sector (9 bits assumes 512-byte sectors)
; DX:AX b?:10	=which sector of FAT to load
			mov di,ax
			shr dx,1
			rcr ax,1
			div word [VAR(bytes_per_sector)]

; remainder is byte offset into FAT sector: put it in SI
			mov si,dx

; quotient in AX is FAT sector: add FAT starting sector
			add ax,[VAR(fat_start)]

; check the FAT buffer to see if this sector is already loaded
; (simple disk cache; speeds things up a little --
; actually, it speeds things up a lot)
			cmp ax,[curr_sector]
			je wf_1
			mov [curr_sector],ax

; read the target FAT sector. FAT12 entries may straddle a sector
; boundary, so read 2 sectors.
			xor dx,dx
			mov cx,2
			call read_sectors_chs
			jc wf_4
wf_1:
; get 16 bits from FAT
			mov ax,[es:bx + si]

; look at DI:0 to see if we want the high 12 bits or the low 12 bits
			shr di,1
			jc wf_2
			and ax,0FFFh	; CY=1: use low 12 bits
			jmp short wf_3
wf_2:
			mov cl,4
			shr ax,cl	; CY=0: use high 12 bits
wf_3:
			mov si,ax

; clear CY bit to signal success
			xor dx,dx
wf_4:
		pop ax
		pop dx
	pop bx
	pop cx
	pop di
	pop es
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATA
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; which sector is in the FAT buffer
; this is relative to partition start, so we need only 16 bits
curr_sector:
	dw -1
ss_name:
	db SS_NAME

; pad with NOPs to offset 510
	times (510 + $$ - $) nop

; 2-byte magic bootsector signature
	db 55h, 0AAh
