/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <hal/video.h>
#include <gadfly/kdefs.h>


/***
 * Local function prototypes
 ***/
void scroll( void );
void clear_to_eol( void );
void newline( void );
void move_cursor( int row, int col );
void save_cursor( void );
void restore_cursor( void );
void get_cursor( int* row, int* col );
int put_cursor( int row, int col );
uchar_t get_video_attributes( void );
void set_video_attributes( uchar_t attrib );
void put_literal( int c );
void update_attributes( void );
void reset( void );
void start_escape( void );
void start_arg( int argNum );
void add_digit( int c );
int get_arg( int argNum );


/***
 * Include proper HAL architecture code
 ***/
#if X86
#include "../hal/x86/HAL_video.c"
#endif


/*
 * Write a string of characters to the screen at current cursor
 * position using current attribute.
 */
void put_string( const char* s )
{
  while( *s != '\0' )
    {
      putc( *s++ );
    }
}


/*
 * Scroll the display one line.
 * We speed things up by copying 4 bytes at a time.
 */
void scroll( void )
{
  unsigned int* v;
  int i, n = NUM_SCROLL_DWORDS;
  unsigned int fill = FILL_DWORD;

  /* Move lines 1..NUMROWS-1 up one position. */
  for( v = (unsigned int*)VIDMEM, i = 0; i < n; ++i ) 
    {
      *v = *(v + NUM_DWORDS_PER_LINE);
      ++v;
    }

  /* Clear out last line. */
  for( v = (unsigned int*)VIDMEM + n, i = 0; i < NUM_DWORDS_PER_LINE; ++i )
    {
      *v++ = fill;
    }
}


/*
 * Clear current cursor position to end of line using
 * current attribute.
 */
void clear_to_eol( void )
{
  int n = (NUMCOLS - s_cons.col);
  unsigned char* v = VIDMEM + s_cons.row*(NUMCOLS*2) + s_cons.col*2;
    
  while (n-- > 0) 
    {
      *v++ = ' ';
      *v++ = s_cons.currentAttr;
    }
}


/*
 * Move to the beginning of the next line, scrolling
 * if necessary.
 */
void newline( void )
{
  ++s_cons.row;
  s_cons.col = 0;
    
  if( s_cons.row == NUMROWS ) 
    {
      scroll();
      s_cons.row = NUMROWS - 1;
    }
}


/*
 * Move the cursor to a new position, stopping at the screen borders.
 */
void move_cursor( int row, int col )
{
  if( row < 0 )
    {
      row = 0;
    }
  else if( row >= NUMROWS )
    {
      row = NUMROWS - 1;
    }

  if( col < 0 )
    {
      col = 0;
    }
  else if( col >= NUMCOLS )
    {
      col = NUMCOLS - 1;
    }

  s_cons.row = row;
  s_cons.col = col;
}


/* Save current cursor position. */
void save_cursor( void )
{
  s_cons.saveRow = s_cons.row;
  s_cons.saveCol = s_cons.col;
}


/* Restore saved cursor position. */
void restore_cursor( void )
{
  s_cons.row = s_cons.saveRow;
  s_cons.col = s_cons.saveCol;
}


/*
 * Get current cursor position.
 */
void get_cursor( int* row, int* col )
{
  *row = s_cons.row;
  *col = s_cons.col;
}

/*
 * Set the current cursor position.
 * Return true if successful, or false if the specified
 * cursor position is invalid.
 */
int put_cursor( int row, int col )
{
  if( row < 0 || row >= NUMROWS || col < 0 || col >= NUMCOLS )
    {
      return 0;
    }

  s_cons.row = row;
  s_cons.col = col;
  HAL_update_cursor();

  return 1;
}


/*
 * Get the current character attribute.
 */
uchar_t get_video_attributes( void )
{
  return s_cons.currentAttr;
}


/*
 * Set the current character attribute.
 */
void set_video_attributes( uchar_t attrib )
{
  s_cons.currentAttr = attrib;
}


/*
 * Write a single character to the screen at current position
 * using current attribute, handling scrolling, special characters, etc.
 */
void putc( int c )
{
 again:
  switch (s_cons.state) {
  case S_NORMAL:
    if (c == ESC)
      start_escape();
    else
      put_literal( c );
    break;

  case S_ESC:
    if (c == '[')
      s_cons.state = S_ESC2;
    else
      reset();
    break;

  case S_ESC2:
    if (ISDIGIT(c)) {
      start_arg(0);
      goto again;
    } else if (c == ';') {
      /* Special case: for "n;m" commands, "n" is implicitly 1 if omitted */
      start_arg(0);
      add_digit('1');
      start_arg(1);
    } else {
      s_cons.state = S_CMD;
      goto again;
    }
    break;

  case S_ARG:
    if (ISDIGIT(c))
      add_digit(c);
    else if (c == ';')
      start_arg(s_cons.numArgs);
    else {
      s_cons.state = S_CMD;
      goto again;
    }
    break;

  case S_CMD:
    switch (c) {
    case 'K': clear_to_eol(); break;
    case 's': save_cursor(); break;
    case 'u': restore_cursor(); break;
    case 'A': move_cursor(s_cons.row - get_arg(0), s_cons.col); break;
    case 'B': move_cursor(s_cons.row + get_arg(0), s_cons.col); break;
    case 'C': move_cursor(s_cons.row, s_cons.col + get_arg(0)); break;
    case 'D': move_cursor(s_cons.row, s_cons.col - get_arg(0)); break;
    case 'm': update_attributes(); break;
    case 'f': case 'H':
      if (s_cons.numArgs == 2) move_cursor(get_arg(0)-1, get_arg(1)-1); break;
    case 'J':
      if (s_cons.numArgs == 1 && get_arg(0) == 2) {
	HAL_clear_screen();
	put_cursor(0, 0);
      }
      break;
    default: break;
    }
    reset();
    break;

  default:
    //KASSERT(false);
    ;
  }

  HAL_update_cursor();
}


/*
 * Put one character to the screen using the current cursor position
 * and attribute, scrolling if needed.  The caller should update
 * the cursor position once all characters have been written.
 */
void put_literal( int c )
{
  int numSpaces;

  switch (c) {
  case '\n':
    clear_to_eol();
    newline();
    break;

  case '\t':
    numSpaces = TABWIDTH - (s_cons.col % TABWIDTH);
    while (numSpaces-- > 0)
      HAL_putc(' ');
    break;

  default:
    HAL_putc(c);
    break;
  }
}


/*
 * Table mapping ANSI colors to VGA text mode colors.
 */
static const uchar_t s_ansiToVgaColor[] = {
  BLACK,RED,GREEN,AMBER,BLUE,MAGENTA,CYAN,GRAY
};

/*
 * Update the attributes specified by the arguments
 * of the escape sequence.
 */
void update_attributes( void )
{
  int i;
  int attr = s_cons.currentAttr & ~(BRIGHT);

  for (i = 0; i < s_cons.numArgs; ++i) {
    int value = s_cons.argList[i];
    if (value == 0)
      attr = DEFAULT_ATTRIBUTE;
    else if (value == 1)
      attr |= BRIGHT;
    else if (value >= 30 && value <= 37)
      attr = (attr & ~0x7) | s_ansiToVgaColor[value - 30];
    else if (value >= 40 && value <= 47)
      attr = (attr & ~(0x7 << 4)) | (s_ansiToVgaColor[value - 40] << 4);
  }
  s_cons.currentAttr = attr;
}


/* Reset to cancel or finish processing an escape sequence. */
void reset( void )
{
  s_cons.state = S_NORMAL;
  s_cons.numArgs = 0;
}


/* Start an escape sequence. */
void start_escape( void )
{
  s_cons.state = S_ESC;
  s_cons.numArgs = 0;
}


/* Start a numeric argument to an escape sequence. */
void start_arg( int argNum )
{
  //    KASSERT(s_cons.numArgs == argNum);
  s_cons.numArgs++;
  s_cons.state = S_ARG;
  if (argNum < MAXARGS)
    s_cons.argList[argNum] = 0;
}


/* Add a digit to current numeric argument. */
void add_digit( int c )
{
  //KASSERT(ISDIGIT(c));
  if (s_cons.numArgs < MAXARGS) {
    int argNum = s_cons.numArgs - 1;
    s_cons.argList[argNum] *= 10;
    s_cons.argList[argNum] += (c - '0');
  }
}

/*
 * Get a numeric argument.
 * Returns zero if that argument was not actually specified.
 */
int get_arg( int argNum )
{
  return argNum < s_cons.numArgs ? s_cons.argList[argNum] : 0;
}


