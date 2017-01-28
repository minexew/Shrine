// vim: set ft=cpp:

#include "::/Doc/Comm"

#define CMD_SOCKET        1
#define CMD_CLOSE         2
#define CMD_CONNECT_TCP   3
#define CMD_SEND          4
#define CMD_RECV          5
#define CMD_RECVALL       6
#define CMD_HELLO         0xAA

#define SOCK_STREAM 1
#define SOCK_DGRAM  2
#define SOCK_RAW    3

#define AF_UNSPEC   0
#define AF_INET     2
#define AF_INET6    10

#define SNAIL_COM         2
#define SNAIL_TIMEOUT     500
#define SNAIL_FRAME_SIZE  112

static U8 ReadByte() {
  U8 chr;
  while (1) {
    if (FifoU8Rem(comm_fifos[SNAIL_COM], &chr))
      return chr;
    else
      Yield;
  }
}

static I8 ReadI8() {
  I8 chr;
  while (1) {
    if (FifoU8Rem(comm_fifos[SNAIL_COM], &chr))
      return chr;
    else
      Yield;
  }
}

static U0 ReadBlock(I64 port, U8* buf, I64 count) {
  while (count) {
    if (FifoU8Rem(comm_fifos[port], buf)) {
      buf++;
      count--;
    }
    else Yield;
  }
}

I8 SnailInit() {
  CommInit8n1(SNAIL_COM, 9600);
  CommBusyPutChar(SNAIL_COM, CMD_HELLO);

  I64 max_time = cnts.jiffies + SNAIL_TIMEOUT * JIFFY_FREQ / 1000;

  do {
    I8 chr;

    if (FifoU8Rem(comm_fifos[SNAIL_COM], &chr))
      return chr;
    else
      Yield;
  }
  while (cnts.jiffies < max_time);

  "$FG,6$Failed to initialize Snail -- make sure COM%d "
  "is properly configured & snail.py is running!\n$FG$", SNAIL_COM;
  throw;
}

I64 socket(I64 domain, I64 type) {
  CommBusyPutChar(SNAIL_COM, CMD_SOCKET);
  CommBusyPutChar(SNAIL_COM, domain);
  CommBusyPutChar(SNAIL_COM, type);
  return ReadI8();
}

I64 close(I64 sockfd) {
  CommBusyPutChar(SNAIL_COM, CMD_CLOSE);
  CommBusyPutChar(SNAIL_COM, sockfd);
  return ReadI8();
}

I64 connectTcp(I64 sockfd, U8* addr, U16 port) {
  CommBusyPutChar(SNAIL_COM, CMD_CONNECT_TCP);
  CommBusyPutChar(SNAIL_COM, sockfd);
  CommBusyPutChar(SNAIL_COM, StrLen(addr));
  CommBusyPutS(SNAIL_COM, addr);
  CommBusyPutChar(SNAIL_COM, port & 0xff);
  CommBusyPutChar(SNAIL_COM, port >> 8);
  return ReadI8();
}

I64 recvall(I64 sockfd, U8* buf, I64 len, I64 flags) {
  I64 total = 0;

  while (len) {
    I64 step = len;

    if (step > SNAIL_FRAME_SIZE)
      step = SNAIL_FRAME_SIZE;

    CommBusyPutChar(SNAIL_COM, CMD_RECVALL);
    CommBusyPutChar(SNAIL_COM, sockfd);
    CommBusyPutChar(SNAIL_COM, step);
    CommBusyPutChar(SNAIL_COM, flags);
    I64 got = ReadI8();

    if (got <= 0)
      return got;

    ReadBlock(SNAIL_COM, buf, got);

    len -= got;
    total += got;
    buf += got;
  }

  return total;
}

I64 send(I64 sockfd, U8* buf, I64 len, I64 flags) {
  // FIXME: use frames
  CommBusyPutChar(SNAIL_COM, CMD_SEND);
  CommBusyPutChar(SNAIL_COM, sockfd);
  CommBusyPutChar(SNAIL_COM, len);
  CommBusyPutChar(SNAIL_COM, flags);
  CommBusyWriteBlk(SNAIL_COM, buf, len);
  return ReadI8();
}

// Higher-level functions

I64 recvLine(I64 sock, U8* buffer, I64 size, I64 flags) {
  I64 got = 0;
  while (got + 1 < size) {
    if (!recvall(sock, buffer + got, 1, flags))
      return -1;

    if (buffer[got] == '\n')
      break;
    else if (buffer[got] != '\r')
      got++;
  }
  // FIXME: safe but incorrect behavior on overflow
  buffer[got] = 0;
  return got;
}

I64 sendString(I64 sockfd, U8* str, I64 flags) {
  return send(sockfd, str, StrLen(str), flags);
}

/*
U0 SnailTest() {
  SnailInit();
  I64 sock = socket(AF_INET, SOCK_STREAM);
  if (connectTcp(sock, "127.0.0.1", 8888)) {
    "$FG,4$Connect failed!\n$FG$";
    return;
  }

  U8* msg = "Yay nigga!\n";
  send(sock, msg, StrLen(msg), 0);
  U8 buf[12];
  I64 len = recvall(sock, buf, 11, 0);
  buf[len] = 0;
  "" buf;
  close(sock);
}

SnailTest;
*/