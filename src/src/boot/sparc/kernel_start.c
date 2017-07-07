/***
 * To build:
 * sun4-gcc -I. -nostdinc -Wall -c start.c
 * sun4-ld -o kernel.tmp -e _kernel_start -N -Ttext 0x5000 -x start.o
 * dd if=kernel.tmp of=vmsteak-sparc bs=32 skip=1 2> /dev/null
 *
 * 1st stage bootloader looks for vmsteak-sparc, which is this code compiled
 *
 ***/

#include "openprom.h"
#include "sbbb.h"

/* these don't count as variable declarations since they are extern */
extern struct PromVec *PromVec;
extern struct BootDir *BootDir;

int main ();

/* entry point */
void kernel_start (struct PromVec *P, struct BootDir *BD)
{
	PromVec = P;
    BootDir = BD;
    main ();
}

/* silly GNU linker */
void __main ()
{
}

struct PromVec *PromVec;
struct BootDir *BootDir;

int main ()
{
	PromVec->printf ("Hello World!\n");
    return 0; /* to please GCC */
}
