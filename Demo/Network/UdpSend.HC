// vim: set ft=c:

// udp-listen.py 15051

#include "::/Adam/Net/Socket"

#define PORT 15051

I64 UdpSend(U8* dest_address) {
  SocketInit();

  I64 sock = socket(AF_INET, SOCK_DGRAM);

  if (sock < 0)
    return -1;

  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(PORT);
  addr.sin_addr.s_addr = 0;
  inet_pton(addr.sin_family, dest_address, &addr.sin_addr);

  U8* message = "hello, world!";
  I64 count = sendto(sock, message, StrLen(message), 0, &addr, sizeof(addr));

  if (count < 0) {
    "$FG,6$sendto: error %d\n$FG$", count;
  }

  close(sock);
  return 0;
}
