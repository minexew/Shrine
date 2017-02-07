// vim: set ft=cpp:

#define SOCK_STREAM 1
#define SOCK_DGRAM  2
#define SOCK_RAW    3

#define AF_UNSPEC   0
#define AF_INET     2
#define AF_INET6    10

I64 SocketInit() { throw; return -1; }
I64 socket(I64, I64) { return -1; }
I64 close(I64) { return -1; }
I64 create_connection(U8*, U16) { return -1; }
I64 recv(I64, U8*, I64, I64) { return -1; }
I64 recvall(I64, U8*, I64, I64) { return -1; }
I64 send(I64, U8*, I64, I64) { return -1; }
I64 recvLine(I64, U8*, I64, I64) { return -1; }
I64 sendString(I64, U8*, I64) { return -1; }
