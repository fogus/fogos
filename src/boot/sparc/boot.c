/*	$OpenBSD: boot.c,v 1.1 1997/09/17 10:46:15 downsj Exp $	*/
/*	$NetBSD: boot.c,v 1.2 1997/09/14 19:27:21 pk Exp $	*/

/*
 * Copyright (c) 1982, 1986, 1990, 1993
 *	The Regents of the University of California.  All rights reserved.
 * Copyright (c) 1998 Sidney Cammeresi.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *        This product includes software developed by the University of
 *        California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * 	@(#)boot.c	8.1 (Berkeley) 6/10/93
 */

#include <sys/param.h>
#include <sys/reboot.h>
#include <a.out.h>
#include <lib/libsa/stand.h>

#include <sparc/stand/common/promdev.h>

static void copyunix __P((int, char *));
static void promsyms __P((int, struct exec *));
int debug;
int netif_debug;

/*
 * Boot device is derived from ROM provided information.
 */
#define	DEFAULT_KERNEL	"vmsteak"

extern char		*version;
unsigned long		esym;
char			*strtab;
int			strtablen;
char			fbuf[80], dbuf[128];

typedef void (*entry_t)__P((caddr_t, int, int, int, long, long));

void	loadfile __P((int, caddr_t));

main()
{
	int	io;
	char	*file;

	prom_init();

	printf(">> SigOps BOOT %s\n", version);

	file = prom_bootfile;
	if (file == 0 || *file == 0)
		file = DEFAULT_KERNEL;

	for (;;) {
		if (prom_boothow & RB_ASKNAME) {
			printf("device[%s]: ", prom_bootdevice);
			gets(dbuf);
			if (dbuf[0])
				prom_bootdevice = dbuf;
			printf("boot: ");
			gets(fbuf);
			if (fbuf[0])
				file = fbuf;
		}
		if ((io = open(file, 0)) >= 0)
			break;
		printf("open: %s: %s\n", file, strerror(errno));
		prom_boothow |= RB_ASKNAME;
	}

	printf("Booting %s @ 0x%x\n", file, LOADADDR);
	loadfile(io, LOADADDR);

	_rtt();
}

/* this stuff is a hack, but it works.  it won't boot openbsd or netbsd, but
 * that's just too bad.  -- sc */
void loadfile (register int io, register caddr_t addr)
{
	register entry_t entry = (entry_t)LOADADDR;
	struct exec x;
	char *name, *a, *b, *c, *d;
	int i;
	unsigned int ventry;

	/* read in the file */
	for (;;)
		if (!(read (io, addr++, 1)))
			break;
	close(io);
	printf ("Loaded 0x%x bytes\n", (unsigned int) addr - 0x4000 - 1);

	/* a few magic numbers here */
	name = (char *) 0x4040;
	a = (char *) 0x4074;
	b = a + 1;
	c = a + 2;
	d = a + 3;

	/* damn intel byte order */
	ventry = (*d << 24) + (*c << 16) + (*b << 8) + *a;
	printf ("Executing %s at 0x%x\n\n", name, 0x5000 + ventry);

	(*((entry_t) 0x5000 + ventry)) ((caddr_t) promvec, 0x4000, 0, 0, 0, 0);
	return;
}

