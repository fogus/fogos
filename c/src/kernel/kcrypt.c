/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <gadfly/kcrypt.h>
#include <gadfly/kdefs.h>
#include <gadfly/kprint.h>


/***
 * Local function prototypes
 ***/


/***
 * Include proper HAL architecture code
 ***/
#if X86
#include "../hal/x86/HAL_crypt.c"
#endif


void add_entropy( unsigned int e )
{
  unsigned int unit = e ^ 0xDEADBEEF;
  kprintf( "\nAdding entropy unit %u", unit );    
}

