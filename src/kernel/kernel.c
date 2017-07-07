/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <gadfly/kprint.h>
#include <gadfly/kcrypt.h>
#include <hal/interrupts.h>
#include <hal/memory.h>
#include <hal/video.h>
#include <hal/crypt.h>
#include <gadfly/kdefs.h>


int k_main( void )
{
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

  add_entropy( i );
  
  /* return to stage1, which will freeze */
  return 0;
}


