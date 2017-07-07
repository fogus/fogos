/***
 *	Author:		Fogus
 *	Website:	http://fogus.me/thunks/osdev.html
 ***/

#include <stdarg.h>
#include <hal/video.h>
#include <string.h>
#include <hal/memory.h>
#include <hal/interrupts.h>
#include <hal/io.h>

#define ESC ((char) 0x1B)
#define DEFAULT_ATTRIBUTE ATTRIB(BLACK, LIGHT_GREEN)

void HAL_update_cursor( void );

enum State {
  S_NORMAL,		/* Normal state - output is echoed verbatim */
  S_ESC,		/* Saw ESC character - begin output escape sequence */
  S_ESC2,		/* Saw '[' character - continue output escape sequence */
  S_ARG,		/* Scanning a numeric argument */
  S_CMD,		/* Command */
};

#define MAXARGS 8	/* Max args that can be passed to esc sequence */

struct Console_State {
  /* Current state information */
  int row, col;
  int saveRow, saveCol;
  unsigned char currentAttr;

  /* Working variables for processing escape sequences. */
  enum State state;
  int argList[MAXARGS];
  int numArgs;
};

static struct Console_State s_cons;

#define NUM_SCREEN_DWORDS ((NUMROWS * NUMCOLS * 2) / 4)
#define NUM_SCROLL_DWORDS (((NUMROWS-1) * NUMCOLS * 2) / 4)
#define NUM_DWORDS_PER_LINE ((NUMCOLS*2)/4)
#define FILL_DWORD (0x00200020 | (s_cons.currentAttr<<24) | (s_cons.currentAttr<<8))


/*
 * Update the location of the hardware cursor.
 */
void HAL_update_cursor( void )
{
  /*
   * The cursor location is a character offset from the beginning
   * of page memory (I think).
   */
  uint_t characterPos = (s_cons.row * NUMCOLS) + s_cons.col;
  uchar_t origAddr;

  /*
   * Save original contents of CRT address register.
   * It is considered good programming practice to restore
   * it to its original value after modifying it.
   */
  origAddr = HAL_peek(CRT_ADDR_REG);
  HAL_io_delay();

  /* Set the high cursor location byte */
  HAL_poke(CRT_ADDR_REG, CRT_CURSOR_LOC_HIGH_REG);
  HAL_io_delay();
  HAL_poke(CRT_DATA_REG, (characterPos>>8) & 0xff);
  HAL_io_delay();

  /* Set the low cursor location byte */
  HAL_poke(CRT_ADDR_REG, CRT_CURSOR_LOC_LOW_REG);
  HAL_io_delay();
  HAL_poke(CRT_DATA_REG, characterPos & 0xff);
  HAL_io_delay();

  /* Restore contents of the CRT address register */
  HAL_poke(CRT_ADDR_REG, origAddr);
}

/* ----------------------------------------------------------------------
 * Public functions
 * ---------------------------------------------------------------------- */

/*
 * Clear the screen using the current attribute.
 */
void HAL_clear_screen( void )
{
  uint_t* v = (uint_t*)VIDMEM;
  int i;
  uint_t fill = FILL_DWORD;

  for( i = 0; i < NUM_SCREEN_DWORDS; ++i )
    {
      *v++ = fill;
    }
}


/*
 * Initialize the screen module.
 */
void HAL_initialize_video(void)
{
  s_cons.row = s_cons.col = 0;
  s_cons.currentAttr = DEFAULT_ATTRIBUTE;
  HAL_clear_screen();
}


/*
 * Write the graphic representation of given character to the screen
 * at current position, with current attribute, scrolling if
 * necessary.
 */
void HAL_putc( int c )
{
  unsigned char* v = VIDMEM + s_cons.row*(NUMCOLS*2) + s_cons.col*2;

  /* Put character at current position */
  *v++ = (unsigned char) c;
  *v = s_cons.currentAttr;

  if (s_cons.col < NUMCOLS - 1)
    {
      ++s_cons.col;
    }
  else
    {
      newline();
    }
}
