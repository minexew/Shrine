#exe {
  if (SNAILNET_NATIVE_DRIVER == NULL) {
    StreamPrint("#include \"::/Adam/Net/SnailLib\"");
  }
}

// Higher-level, utility functions

I64 recvLine(I64 sock, U8* buffer, I64 size, I64 flags) {
  I64 got = 0;
  while (got + 1 < size) {
    if (!recv(sock, buffer + got, 1, flags))
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

I64 sendall(I64 sockfd, U8* buf, I64 len, I64 flags) {
  I64 total = 0;

  while (len) {
    I64 sent = send(sockfd, buf, len, flags);
    if (sent > 0) {
      buf += sent;
      total += sent;
      len -= sent;
    }
    else
      break;
  }

  return total;
}

I64 sendString(I64 sockfd, U8* str, I64 flags) {
  return sendall(sockfd, str, StrLen(str), flags);
}
