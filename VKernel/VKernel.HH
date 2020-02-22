#define VSYSCALL_PUTCHAR    1
#define VSYSCALL_SETFS      2
#define VSYSCALL_USLEEP     3

// neutralize CLI instructions
#define CLI

// TODO: not public
public _extern _VKSTART64 U0 VKStart64();
public _extern _VSYSCALL I64 VSysCall(I64 num, I64 arg1, I64 arg2, I64 arg3);
