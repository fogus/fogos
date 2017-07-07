/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <hal/memory.h>

void setup_gdt( void );


void HAL_initialize_memory( void )
{
  setup_gdt();
}


unsigned char HAL_peek( unsigned short loc )
{
  unsigned char ret;

  __asm__ __volatile__( "inb %1,%0" 
			: "=a"(ret) 
			: "d"(loc) );
		
  return ret;		
}


void HAL_poke( unsigned loc, unsigned value )
{
  __asm__ __volatile__( "outb %b0,%w1"
			:
			: "a"(value), "d"(loc));	
}


void HAL_count_memory( void )
{
}


void setup_gdt( void )
{
}

