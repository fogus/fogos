/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#ifndef _INTERRUPTS_H_
#define _INTERRUPTS_H_

void HAL_initialize_interrupts( void );
unsigned char HAL_disable_ints( void );
void HAL_enable_ints( void );

#endif
