/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <hal/io.h>

/*
 * Short delay.  May be needed when talking to some
 * (slow) I/O devices.
 */
void HAL_io_delay( void )
{
  unsigned char value = 0;
  __asm__ __volatile__ (
			"outb %0, $0x80"
			:
			: "a" (value)
			);
}
