/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#ifndef _VIDEO_H_
#define _VIDEO_H_

#define BLACK   	0
#define BLUE    	1
#define GREEN   	2
#define CYAN    	3
#define RED     	4
#define MAGENTA 	5
#define AMBER   	6
#define GRAY    	7
#define BRIGHT  	8
#define LIGHT_BLUE 	9
#define LIGHT_GREEN	11
#define LIGHT_RED	12
#define DARK_PINK	13
#define YELLOW		14
#define WHITE		15

#define ATTRIB(bg,fg) ((fg)|((bg)<<4))

#define NUMCOLS 80
#define NUMROWS 25

#define TABWIDTH 8


/*
 * VGA hardware stuff, for accessing the text display
 * memory and controlling the cursor
 */
#define VIDMEM_ADDR 0xb8000
#define VIDMEM ((unsigned char*) VIDMEM_ADDR)
#define CRT_ADDR_REG 0x3D4
#define CRT_DATA_REG 0x3D5
#define CRT_CURSOR_LOC_HIGH_REG 0x0E
#define CRT_CURSOR_LOC_LOW_REG 0x0F

void HAL_initialize_video( void );
//void HAL_clear_screen( void );
//void HAL_putc( int c );

void put_string( const char* s );
void putc( int c );

#define MIN(a,b) ({typeof (a) _a = (a); typeof (b) _b = (b); (_a < _b) ? _a : _b; })
#define MAX(a,b) ({typeof (a) _a = (a); typeof (b) _b = (b); (_a < _b) ? _a : _b; })

/*
 * Some ASCII character access and manipulation macros.
 */
#define ISDIGIT(c) ((c) >= '0' && (c) <= '9')
#define TOLOWER(c) (((c) >= 'A' && (c) <= 'Z') ? ((c) + ('a' - 'A')) : (c))
#define TOUPPER(c) (((c) >= 'a' && (c) <= 'z') ? ((c) - ('a' - 'A')) : (c))

#define NDEBUG

#endif 
