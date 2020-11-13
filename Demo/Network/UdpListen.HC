// vim: set ft=c:

// udp-send.py 192.168.1.10 15051 "Hello World!"

#include "::/Adam/Net/Socket"

#define PORT 15051

I64 UdpListen() {
  SocketInit();

  I64 sock = socket(AF_INET, SOCK_DGRAM);

  if (sock < 0)
    return -1;

  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(PORT);
  addr.sin_addr.s_addr = INADDR_ANY;

  if (bind(sock, &addr, sizeof(addr)) < 0) {
    close(sock);
    "$FG,4$UdpListen: failed to bind to port %d\n$FG$", PORT;
    return -1;
  }

  "$FG,2$Listening on port %d\n$FG$", PORT;

  while (1) {
    U8 buffer[2048 + 1];
    U8 addr_buffer[INET_ADDRSTRLEN];
    I64 count = recvfrom(sock, buffer, sizeof(buffer) - 1, 0, &addr, sizeof(addr));

    if (count == 0)
      break;

    if (count < 0) {
      "$FG,6$recvfrom: error %d\n$FG$", count;
    }
    else {
      buffer[count] = 0;

      inet_ntop(addr.sin_family, &addr.sin_addr, addr_buffer, sizeof(addr_buffer));

      "$FG,8$Received %d bytes from %s:%d:\n$FG$%s\n", count,
          addr_buffer, ntohs(addr.sin_port), buffer;
    }
  }

  close(sock);
  return 0;
}
