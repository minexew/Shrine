#define VSYSCALL_MEMSIZE    1
#define VSYSCALL_SETFS      2
#define VSYSCALL_SETGS      3
#define VSYSCALL_USLEEP     4
#define VSYSCALL_PUTCHAR    5
#define VSYSCALL_STAT       6
#define VSYSCALL_STATCLUS   7
#define VSYSCALL_FREAD      8
#define VSYSCALL_READ       9

// neutralize CLI instructions
#define CLI

class CHostFsStat {
	U16 attr, pad[3];
    I64 clus, size;
    U8* abs_path;
};

// TODO: not public
public _extern _VKSTART64 U0 VKStart64();
public _extern _VSYSCALL I64 VSysCall(I64 num, I64 arg1, I64 arg2, I64 arg3);
