utput will be an ELF file, that can be 
   loaded by OpenFirmare 3.0 on a PowerMac. 
*/ 
OUTPUT_FORMAT("elf32-powerpc") 

/* Defined in head.cpp */ 
ENTRY(ld_start) 
SECTIONS 
{ 

 /* Kernel will be linked at 2MB. */ 
 . = 0x200000; 

 /* The text section is already page 
    aligned since 2MB is page aligned. 
 */ 
 .text : { 

  /* Symbols to mark start of section. */ 
  ld_text = .; 

  /* Code. */ 
  *(.text*) 

  /* C++ templates/vtables. */ 
  *(.gnu.linkonce.t.*) 

  /* Read-only data (ELF only). */ 
  *(.rodata*) 
  *(.gnu.linkonce.r.*) 

  /* C++ global/static constructors. */ 
  ld_text_ctors = .; 
  *(SORT(.ctor*)) 
  ld_text_ctors_end = .; 
  ld_text_end = .; 
 } 

 /* Page-align (4K) the data section. */ 
 .data ALIGN(0x1000): { 
  ld_data = .; 

  /* Data. */ 
  *(.data*) 
  *(.gnu.linkonce.d.*) 
  ld_data_end = .; 
 } 

 /* Page-align (4K) the BSS section. */ 
 .bss ALIGN(0x1000): { 
  ld_bss = .; 

  /* BSS. */ 
  *(.bss*) 
  *(.gnu.linkonce.b.*) 

  /* "common" variables. */ 
  *(COMMON) 
  ld_bss_end = .; 
 } 

 /* Page-align (4K) the stack section. */ 
 .stack ALIGN(0x1000): { 
  ld_stack = .; 

  /* Stack will be 16K */ 
  . = ld_stack + 0x4000; 
  ld_stack_end = .; 
 } 
 ld_end = .; 

} 


