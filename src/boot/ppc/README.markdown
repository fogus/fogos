s how to compile and link it: 
1) Since my host development system is OS X 10.4.2, I had to 
cross-compile binutils and GCC for powerpc-linux. Here is the configure 
command I passed to configure GCC4 prior to compiling - 

../gcc-4.0.2/configure --target=powerpc-linux 
--prefix=/Users/andreywarkentin/cr 
ossdev/powerpc-linux --disable-shared --disable-threads 
--enable-languages=c,c++ --with-newlib 

2) Now to actually compile the ``kernel'' 
   a) powerpc-linux-g++ -Wall -fno-rtti -nostdlib -fno-builtin 
-fno-exceptions -fno-leading-underscore -c main.c 
   b) powerpc-linux-ld  -T kernel.ld main.o -o kernel.elf 
   c) Copy kernel.elf to / just to simplify booting. 

3) To boot on my machine, first get into OF, then type - 
    boot hd:,/kernel.elf 

4) You should see "Hello World!" and be returned back to OF. Note that 
trying this a second time will fail with a "CLAIM Failed!" error 
message. AFAIK, this is because OF never freed the memory it claimed to 
load your kernel into after the kernel returned back to the ROM 
monitor. (mac-boot won't work either, without crashing). A simple 
'reset-all' cures all. 

