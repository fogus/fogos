/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <hal/io.h>
#include <gadfly/kdefs.h>


/***
 * Local function prototypes
 ***/


/***
 * Include proper HAL architecture code
 ***/
#if X86
#include "../hal/x86/HAL_io.c"
#endif
