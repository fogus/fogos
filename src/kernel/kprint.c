/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/
 
#include <hal/video.h>
#include <stdarg.h>

void print_number( unsigned int num, int base );
char get_ascii( char ch );


void kprint( const char* s )
{
  put_string( s );	
}


void kprintf( const char* msg, ... )
{
  int i;

  va_list args;

  va_start( args, msg );
	
  for( i=0; msg[i] != '\0'; i++ )
    {
      if( msg[i] == '%' )
	{
	  i++;
			
	  switch( msg[i] )
	    {
	    case 's':
	      {
		kprint( va_arg( args, char*));
		break;
	      }	
	    case '%':
	      {
		putc( '%' );	
		break;
	      }	
	    case 'c':
	      {
		putc( va_arg( args, char));
		break;
	      }
	    case 'i':
	    case 'd':
	      {
		unsigned int num = va_arg( args, int);

		if( num > (0xFFFFFFFF/2) )
		  {
		    putc( '-' );
		    print_number( ~num+1, 10);
		    break;
		  }
                
		print_number( num, 10);
		break;
	      }
	    case 'x':
	      {
		print_number( va_arg( args, unsigned int), 16);
		break;
	      }
	    case 'u':
	      {
		print_number( va_arg( args, unsigned int), 10);
		break;
	      }
	    case '\0':
	      {
		i--;
		break;	
	      }
	    default:
	      {
		break;
	      }
	    }	
	}
      else
	{
	  putc( msg[i] );	
	}	
    }

  va_end( args );
}


void print_number( unsigned int num, int base )
{
  unsigned int div;

  if( (div=num/base) )
    {
      print_number( div, base );
    }

  putc( get_ascii( num % base));
}


char get_ascii( char ch )
{
  char valor = '0' + ch;

  if( valor > '9' )
    {
      valor += 7;
    }

  return valor;
}

