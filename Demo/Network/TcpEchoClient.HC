// vim: set ft=c:

#include "::/Adam/Net/Socket"

#define PORT 8000

I64 TcpEchoClient(U8* dest_address) {
  SocketInit();

  I64 sock = socket(AF_INET, SOCK_STREAM);

  if (sock < 0)
    return -1;

  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(PORT);
  addr.sin_addr.s_addr = 0;
  inet_pton(addr.sin_family, dest_address, &addr.sin_addr);

  I64 error = connect(sock, &addr, sizeof(addr));

  if (error < 0) {
    "$FG,6$connect: error %d\n$FG$", error;
    return -1;
  }

  U8* message = "hello, world!\n\n";
  I64 count = send(sock, message, StrLen(message), 0);

  if (count < 0) {
    "$FG,6$send: error %d\n$FG$", count;
    return -1;
  }

  U8 buffer[2048 + 1];
  count = recv(sock, buffer, sizeof(buffer) - 1, 0);

  if (count <= 0) {
    "$FG,6$recv: error %d\n$FG$", count;
  }
  else {
    buffer[count] = 0;
    "$FG,8$Received %d bytes:\n$FG$%s\n", count, buffer;
  }

  close(sock);
  return 0;
}
