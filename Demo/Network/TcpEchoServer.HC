// vim: set ft=c:

#include "::/Adam/Net/Socket"

#define PORT 8000

U0 TcpEchoSession(CTcpSocket* client) {
  U8 buffer[2048 + 1];
  I64 count = recv(client, buffer, sizeof(buffer) - 1, 0);

  if (count <= 0) {
    "$FG,6$recv: error %d\n$FG$", count;
  }
  else {
    buffer[count] = 0;
    "$FG,8$Received %d bytes:\n$FG$%s\n", count, buffer;
  }

  send(client, buffer, count, 0);

  close(client);
}

I64 TcpEchoServer() {
  SocketInit();

  I64 sock = socket(AF_INET, SOCK_STREAM);

  if (sock < 0)
    return -1;

  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(PORT);
  addr.sin_addr.s_addr = INADDR_ANY;

  if (bind(sock, &addr, sizeof(addr)) < 0) {
    close(sock);
    "$FG,4$TcpEchoServer: failed to bind to port %d\n$FG$", PORT;
    return -1;
  }

  I64 error = listen(sock, 1);

  if (error < 0) {
    "$FG,6$listen: error %d\n$FG$", error;
    return -1;
  }

  "$FG,2$Listening on port %d\n$FG$", PORT;

  while (1) {
    I64 client = accept(sock, 0, 0);
    if (client)
      Spawn(&TcpEchoSession, client);
    else
      break;
    Yield; // loop unconditionally
  }
  close(sock);
  return 0;
}
