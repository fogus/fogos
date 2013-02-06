nclude <stdarg.h> 

typedef void *prom_handle; 
typedef void *ihandle; 

struct prom_args { 
     const char *service; 
     int nargs; 
     int nret; 
     void *args[10]; 

}; 

typedef int (*prom_entry)(struct prom_args *); 
prom_entry prom; 
prom_handle prom_stdout; 
ihandle prom_chosen; 

void * 
call_prom (const char *service, int nargs, int nret, ...) 
{ 
  va_list list; 
  int i; 
  struct prom_args prom_args; 

  prom_args.service = service; 
  prom_args.nargs = nargs; 
  prom_args.nret = nret; 
  va_start (list, nret); 
  for (i = 0; i < nargs; ++i) 
    prom_args.args[i] = va_arg(list, void *); 
  va_end(list); 
  for (i = 0; i < nret; ++i) 
    prom_args.args[i + nargs] = 0; 
  prom (&prom_args); 
  if (nret > 0) 
    return prom_args.args[nargs]; 
  else 
    return 0; 

} 

void 
prom_exit () 
{ 
  call_prom ("exit", 0, 0); 
} 

int 
prom_write (prom_handle file, void *buf, int n) 
{ 
  return (int)call_prom ("write", 3, 1, file, buf, n); 
} 

int 
prom_getprop (prom_handle pack, char *name, void *mem, int len) 
{ 
  return (int)call_prom ("getprop", 4, 1, pack, name, mem, len); 
} 

int 
prom_get_chosen (char *name, void *mem, int len) 
{ 
  return prom_getprop (prom_chosen, name, mem, len); 
} 

prom_handle 
prom_finddevice (char *name) 
{ 
  return call_prom ("finddevice", 1, 1, name); 
} 

void 
prom_init (prom_entry pp) 
{ 
  prom = pp; 
  prom_chosen = prom_finddevice ("/chosen"); 
  if (prom_chosen == (void *)-1) 
    prom_exit (); 
  if (prom_get_chosen ("stdout", &prom_stdout, sizeof(prom_stdout)) <= 
0) 
    prom_exit(); 
} 

extern "C" int ld_start(unsigned long r3, 
                        unsigned long r4, 
                        unsigned long r5) 
{ 
  char *blah = "Hello World!\n"; 
  prom_init((prom_entry)r5); 
  prom_write(prom_stdout, (void*)blah, 13); 
  prom_exit(); 
  return 0; 
} 


