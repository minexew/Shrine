asm {
USE64
_VSYSCALL::
		PUSH RDI
		PUSH RSI
		PUSH RDX
		PUSH RCX
		PUSH R10
		// inverse of https://www.jwhitham.org/2015/07/redirecting-system-calls-from-c-library.html
		// Arg 0 (syscall number)
		//MOV RDI, RAX
		MOV U64 RDI, 48[RSP]
		// Arg 1
		//MOV RSI, RDI
		MOV U64 RSI, 56[RSP]
		// Arg 2
		//MOV RDX, RSI
		MOV U64 RDX, 64[RSP]
		// Arg 3
		//MOV RCX, RDX
		MOV U64 RCX, 72[RSP]

		MOV U64 RAX, [_VSYSCALL_DISPATCHER]
		CALL RAX

		POP R10
		POP RCX
		POP RDX
		POP RSI
		POP RDI

		RET1 32

_VSYSCALL_DISPATCHER::
		// This gets patched by the loader
		DU64 0;
}
