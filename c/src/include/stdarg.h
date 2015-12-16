/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

// if your wondering where LASTARG is defined, it happens in the compilation stage
#define	va_start( AP, LASTARG )					\
  ( AP = ( ( va_list ) & ( LASTARG ) + VA_SIZE( LASTARG ) ) )

// same with TYPE
#define va_arg( AP, TYPE )					\
  ( AP += __va_rounded_size ( TYPE ),				\
    * ( ( TYPE * ) ( AP - __va_rounded_size ( TYPE ) ) ) )

#define __va_rounded_size( TYPE )					\
  ( ( ( sizeof ( TYPE ) + sizeof ( int ) - 1 ) / sizeof ( int ) ) * sizeof ( int ) )

#define	VA_SIZE( TYPE )					\
  ( ( sizeof( TYPE ) + sizeof( STACKITEM ) - 1 )	\
    & ~( sizeof( STACKITEM ) - 1 ) )

#define	STACKITEM	int

#define va_end(AP)	

// typedefs:
typedef unsigned char *va_list;

#endif

// End of stdarg.h
