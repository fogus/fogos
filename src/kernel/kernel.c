/***
 *  Author:   Fogus
 *  Website:  http://fogus.me/thunks/osdev.html
 *
 *  Boot path recap (ties to stage1.asm):
 *    - GRUB (Multiboot) loads the kernel at 0x0010_0000 (1 MiB) and jumps to _start.
 *      - QEMU providing this capability for now
 *    - stage1.asm places a Multiboot header, then does:
 *         push ebx   ; Multiboot info structure pointer
 *         push eax   ; Multiboot magic (0x2BADB002)
 *         call k_main
 *         jmp $      ; if k_main returns, freeze forever
 *
 *    - This k_main currently ignores those two pushed arguments (they’re still on the
 *      stack but we don’t read them). If you later want them:
 *
 *          int k_main(unsigned long multiboot_magic, unsigned long mbi_addr)
 *          { ... }
 *
 *      and in stage1.asm keep the pushes in that order (ebx then eax) so the C ABI
 *      (cdecl) sees them as (magic, mbi).
 */
#include <gadfly/kprint.h>
#include <gadfly/kcrypt.h>
#include <hal/interrupts.h>
#include <hal/memory.h>
#include <hal/video.h>
#include <hal/crypt.h>
#include <gadfly/kdefs.h>


/**
 * k_main is the C entrypoint called by stage1.asm.
 * Execution context on entry:
 *   - CPU already in 32-bit protected mode (GRUB did this).
 *   - Paging typically OFF (unless you enable it).
 *   - Interrupts usually disabled; no IDT is installed yet (install one ASAP).
 *   - Stack is valid (from the bootloader), but you should establish your own soon.
 */
int k_main( void )
{
    /*
     * Bring up essential subsystems in a safe order:
     *   1) Interrupts: install a valid IDT so stray faults don’t triple-fault the CPU.
     *   2) Memory: discover physical memory, set up allocators/bitmaps (paging can come later).
     *   3) Video: get VGA text output online for diagnostics (kprintf/putc).
     *
     * Note: These names reflect a HAL-first design: k_main orchestrates; HAL touches hardware.
     */
    HAL_initialize_interrupts();
    HAL_initialize_memory();
    HAL_initialize_video();

    /* Display message */
  
    kprintf( "Initializing FogOS version %s\n", GADFLY_VERSION );

    kprintf( "Testing kprintf( <string>) : %s \n", "worked!" );
    kprintf( "Testing kprintf( <char>)   : %c \n", 'Q' );
    kprintf( "Testing kprintf( <uint>)   : %u \n", 42 );  
    kprintf( "Testing kprintf( <int>)   : %d \n", 1239928 );
    kprintf( "Testing kprintf( <int>)   : %i \n", -8177 );
    kprintf( "Testing kprintf( <hex>)   : %x \n", 42 );

    int i;
    
    for( i=0; i<256; i++ )
    {
	putc( '9' - (i%10) );	
    }

    /*
     * Early entropy hook:
     * - Seeds your kernel’s entropy pool right away (architectural intent: crypto at HAL).
     * - Using loop counter ‘i’ is a placeholder; later you can mix in:
     *     - TSC reads (rdtsc),
     *     - interrupt timing jitter,
     *     - uninitialized SRAM noise (careful),
     *     - device/keyboard timings,
     *     - CPUID-based unique salts, etc.
     */
    add_entropy( i );
  
    /* return to stage1, which will freeze */
    return 0;
}
