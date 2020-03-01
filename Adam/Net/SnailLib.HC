#include "::/Doc/Comm"

#define CMD_SOCKET        1
#define CMD_CLOSE         2
#define CMD_CONNECT_TCP   3
#define CMD_SEND          4
#define CMD_RECV          5
#define CMD_HELLO         0xAA

#define SOCK_STREAM 1
#define SOCK_DGRAM  2
#define SOCK_RAW    3

#define AF_UNSPEC   0
#define AF_INET     2
#define AF_INET6    10

#define SNAIL_COM         3
#define SNAIL_TIMEOUT     500
#define SNAIL_FRAME_SIZE  112

static CComm* snail_comm;

static U8 ReadByte() {
  U8 chr;
  while (1) {
    if (FifoU8Rem(snail_comm->RX_fifo, &chr))
      return chr;
    else
      Yield;
  }
}

static I8 ReadI8() {
  I8 chr;
  while (1) {
    if (FifoU8Rem(snail_comm->RX_fifo, &chr))
      return chr;
    else
      Yield;
  }
}

static U0 ReadBlock(U8* buf, I64 count) {
  while (count) {
    if (FifoU8Rem(snail_comm->RX_fifo, buf)) {
      buf++;
      count--;
    }
    else Yield;
  }
}

I64 SocketInit() {
  U8 chr;

  snail_comm = CommInit8n1(SNAIL_COM, 9600);
  while (FifoU8Rem(snail_comm->RX_fifo, &chr)) {}

  CommPutChar(SNAIL_COM, CMD_HELLO);

  I64 max_time = cnts.jiffies + SNAIL_TIMEOUT * JIFFY_FREQ / 1000;

  do {
    if (FifoU8Rem(snail_comm->RX_fifo, &chr)) {
      if (chr == CMD_HELLO) {
        return 0;
      }
      else {
        "$FG,6$Failed to initialize Snail -- wrong hello 0x%02X\n", chr;
        "Are you using the right version of snail.py?\n$FG$";
        throw;
      }
      return chr;
    }
    else
      Yield;
  }
  while (cnts.jiffies < max_time);

  "$FG,6$Failed to initialize Snail -- make sure COM%d "
  "is properly configured & snail.py is running!\n$FG$", SNAIL_COM;
  throw;
}

I64 socket(I64 domain, I64 type) {
  CommPutChar(SNAIL_COM, CMD_SOCKET);
  CommPutChar(SNAIL_COM, domain);
  CommPutChar(SNAIL_COM, type);
  return ReadI8();
}

I64 close(I64 sockfd) {
  CommPutChar(SNAIL_COM, CMD_CLOSE);
  CommPutChar(SNAIL_COM, sockfd);
  return ReadI8();
}

I64 create_connection(U8* addr, U16 port) {
  I64 sockfd = socket(AF_INET, SOCK_STREAM);

  if (sockfd < 0)
    return sockfd;

  CommPutChar(SNAIL_COM, CMD_CONNECT_TCP);
  CommPutChar(SNAIL_COM, sockfd);
  CommPutChar(SNAIL_COM, StrLen(addr));
  CommPutS(SNAIL_COM, addr);
  CommPutChar(SNAIL_COM, port & 0xff);
  CommPutChar(SNAIL_COM, port >> 8);

  I64 error = ReadI8();
  if (error < 0) {
    close(sockfd);
    return error;
  }

  return sockfd;
}

I64 recv(I64 sockfd, U8* buf, I64 len, I64 flags) {
  // This will be problematic for UDP
  if (len > SNAIL_FRAME_SIZE)
    len = SNAIL_FRAME_SIZE;

  CommPutChar(SNAIL_COM, CMD_RECV);
  CommPutChar(SNAIL_COM, sockfd);
  CommPutChar(SNAIL_COM, len);
  CommPutChar(SNAIL_COM, flags);
  I64 got = ReadI8();

  if (got > 0)
    ReadBlock(buf, got);

  return got;
}

I64 send(I64 sockfd, U8* buf, I64 len, I64 flags) {
  // FIXME: use frames
  CommPutChar(SNAIL_COM, CMD_SEND);
  CommPutChar(SNAIL_COM, sockfd);
  CommPutChar(SNAIL_COM, len);
  CommPutChar(SNAIL_COM, flags);
  CommPutBlk(SNAIL_COM, buf, len);
  return ReadI8();
}
