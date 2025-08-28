global _start          ; Export the symbol "_start" as the entry point
extern k_main          ; Declare the kernel C entry function (defined in C code)

_start:
    jmp start2         ; Jump forward, skipping over the Multiboot header

align 4                ; Align the following data on a 4-byte boundary
dd 0x1badb002          ; Multiboot "magic number" (QEMU+GRUB looks for this)
dd 0                   ; Flags = 0 (no special requests: no memory map, no modules, etc.)
dd 0 - 0x1badb002      ; Checksum so that (magic + flags + checksum) == 0

start2:
    push ebx           ; Save the Multiboot information structure pointer (from GRUB)
    push eax           ; Save the magic number passed by GRUB
    call k_main        ; Call the C entrypoint for the kernel
    jmp $              ; Infinite loop to halt if k_main ever returns
