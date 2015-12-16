Build a toolchain
This part may not be necessary depending on your environment. If you intend to develop on a different architecture machine, you will obviously need a different toolchain. My personal setup is a Pentium Pro as a workstation and a SS 1+ as a test bed. The machines are connected by Ethernet and I run minicom on the PPro to control the 1+ over the serial port.

First get the current binutils source from your favourite ftp mirror. Building binutils is rather straightforward and should offer no surprises. After unpacking the distribution, to build the cross-assembler, cross-linker, and friends, do a

    $ ./configure --prefix=/usr/local/xdev-sun --target=sun4
    $ make
    $ su
    # make install

Of course, you can change the prefix argument to whatever you want. You can even install them in the default /usr/local if you want since the configure script will detect that you are building a cross-toolchain and name the binaries sun4-gas, sun4-ld, and such.

Next is the cross-compiler. Unfortunately, this is not completely trivial. The problem is that GCC doesn't know how to open code certain basic functions for SPARC processors that reside in libgcc.a. Since libgcc.a needs to be library for a SPARC machine, you can't build it with your native compiler. You also can't build it with the cross-compiler since that would make those functions compile into infinite recursion. Basically, you have to build libgcc.a (actually, only libgcc2.a) on a SPARC machine. If you have an operating system on your SPARC computer or access to one that does, you can do the following to generate the library by building part of a native compiler on another system using its native compiler.

    $ ./configure
    $ make libgcc2.a

Then just transfer libgcc2.a to the machine building the cross-compiler and hack the Makefile to not build libgcc2.a. Beware and back up the compiled libgcc2.a first since you will not hack it right the first time and it will try to rebuild libgcc2.a and it will overwrite the copy you put there. Clear? To build the rest, do

    $ ./configure --prefix=/usr/local/xdev-sun --target=sun4
    $ make LANGUAGES=C
    $ su
    # make install

If you use C++, then change then add that to the languages variable. Note that unlike when building a native compiler, the cross-compiler does not get recompiled with itself.

Set up your computer
Your SPARC computer will need a bit of setup. Hopefully you have an operating system already installed on it. If not, you should consider doing so, even if it has to mount its root filesystem over NFS.

Unfortunately, the Solaris/NetBSD/OpenBSD bootloaders were designed to load a.out executables, not the SBBB boot images that we in SigOps use. For this reason, you will need to use my modified version of the OpenBSD second-stage bootstrap program. You have two options here:

    * boot from the network and send my second-stage as the initial boot program and have it load the SBBB boot image over NFS using RARP, bootparamd, and friends
    * dedicate a small partition to booting of your home-grown OS and install the normal OpenBSD boot block there with my modified second-stage

The first option is trivial; however, my 1+ seems to be very flaky about booting from the network, so I use the second option. You will probably want to have about two or three megabytes for this filesystem. Additionally, you will have to have another OS installed to copy the boot image into this filesystem before booting it. Edit your disklabel, create a filesystem on the new slice, and add it to your fstab. I assume it is sd0d and mounted under /xdev.

To build my second-stage bootstrap program, you will need the source. If you don't want to build it, you can get by with the binary and skip a few steps below. Do the following to build and install it into the new filesystem:

    # cd /sys/arch/sparc/stand/boot
    # mv boot.c boot.c.old
    # cp ~/boot.c .
    # make
    # mv /usr/mdec/boot /usr/mdec/boot.old
    # mv boot /usr/mdec
    # halt
    ok boot -s
    ...
    # mount -a
    # /usr/mdec/binstall ffs /xdev
    # halt
    ok boot

Note that you must reboot into single user mode to install the boot block and second-stage bootstrap program since the kernel will not let you do so while in secure mode.

Of course, if you get the old style `>' prompt from the monitor, you will need to do

    >n
    ok setenv sunmon-compat? false
    ok setenv security-mode none

at your earliest convenience.

== kernel_start.c ==
With your cross-development tools in hand, it's time to start coding. Fortunately, Sun has done a lot of the work for you here. Unlike i386s, SPARC computers have a complete printf function in their PROMs! This is very handy to say the least.

The name of your entry point can be whatever you want it to be. I call mine kernel_start. Make sure that it is the first function in the source file and that it is before any variable declarations. The only thing that may come before the definition of your entry point are function prototypes. If anything else is before it, the GNU linker will not produce correct code. Another quirk with the linker (I've got the feeling that it could use some work) is that it expects the C symbol __main to be defined somewhere. I have no idea why, but nothing will link without one. A third oddity is that it mangles names by prepending underscores to all C symbols, so anything declared in a C file that gets referenced in an assembly file needs to have an underscore prepended to its name.

For interfacing with the PROM, you will want a copy of OpenBSD's bsd_openprom.h. Note that this file is under the BSD licence. To that file, you will want to add

    typedef char *caddr_t;
    typedef unsigned int u_int;

The thing that you will quickly become intimately familiar with and grow to love is this structure called the PROM vector. Known as `struct promvec' in the OpenBSD header file, it provides all sorts of data and function pointers to neat things in the PROM. Read the file for details, although I will discuss some points later.

My bootloader will pass the PROM vector and address of the SBBB image (always 0x4000, but code to an interface, not an implementation! [Gamma1995]) when calling your entry point. These are parameters if your entry point is in C. If your entry point is in assembly, they will be in %o0 and %o1. Minimally, you will need something resembling this in C:

    #include "openprom.h"
    #include "sbbb.h"

    /* these don't count as variable declarations since they are extern */
    extern struct PromVec *PromVec;
    extern struct BootDir *BootDir;

    int main ();

    /* entry point */
    void kernel_start (struct PromVec *P, struct BootDir *BD)
    {
      PromVec = P;
      BootDir = BD;
      main ();
    }

    /* silly GNU linker */
    void __main ()
    {
    }

    struct PromVec *PromVec;
    struct BootDir *BootDir;

    int main ()
    {
      PromVec->printf ("Hello World!\n");
      return 0; /* to please GCC */
    }

To compile and link this bohemoth, you will want to write an appropriate Makefile. See the SigOps tutorial for one for i386. Mine is too complex to give here, but assuming you called the above file start.c, from the shell you would do

    $ sun4-gcc -I. -nostdinc -Wall -c start.c
    $ sun4-ld -o kernel.tmp -e _kernel_start -N -Ttext 0x5000 -x start.o
    $ dd if=kernel.tmp of=vmsteak-sparc bs=32 skip=1 2> /dev/null

The third step strips off the a.out header. It is not strictly necessary right now, but beware that your entry point will be at 0x5020 if you don't remove it. You may as well get used to doing it now since a very good reason for doing so will be given in the next section. This procedure should leave you with an executable called vmsteak-sparc. Package this up with Brian Swetland's uBoot system, and you're ready to fly. The image should be called vmsteak since that is the filename my bootloader will look for. If you don't like that name, change it in boot.c and recompile the second-stage.

If you need to use an entry point other than the beginning of the file (0x5000) you will need to give a ventry parameter in your bootmaker configuration file. My bootloader will grab that from the SBBB directory, swap bytes to big endian order, and jump to your offset. Note that the data in the directory are stored in little endian byte order, so you have to swap bytes when you read it later on.

Let's boot this bad boy, assuming my setup as usual:

    $ cp vmsteak /xdev
    $ su
    # halt
    ok boot sd(,,3)          -- or `boot disk:d' or `boot /sbus/esp/sd@0,0:d'
                                depending on your PROM version

Assuming everything goes well, you should see something resembling the following:

    Booting from: sd(0,0,3)                                                         
    >> SigOps BOOT 1.0
    Booting vmsteak @ 0x4000
    Loaded 0x2000 bytes
    Executing KERN:vmsteak at 0x5000

    Hello World!
    Program terminated
    ok

Congratulations, you're an OS coder.
