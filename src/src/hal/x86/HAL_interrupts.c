/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

void setup_idt( void );


void HAL_initialize_interrupts( void )
{
  setup_idt();
}


void setup_idt( void )
{
    
}


unsigned char HAL_disable_ints( void )
{
  unsigned ret_val;

  __asm__ __volatile__( "pushfl\n"
			"popl %0\n"
			"cli"
			: "=a"(ret_val)
			: );
		
  return ret_val;	
}


void HAL_enable_ints( void )
{
  __asm__ __volatile__( "sti"
			:
			:
			);	
}


