// vim: set ft=cpp:

#include "::/Adam/Net/Socket"

#define HTTP_ECONNECT   (-101)
#define HTTP_EPROTOCOL  (-102)
#define HTTP_EREQUEST   (-103)

I64 HttpOpenGet(U8* host, U16 port = 0, U8* path, I64* len_out) {
  U8 line[256];
  I64 error = 0;

  I64 sock = socket(AF_INET, SOCK_STREAM);

  if (!port)
    port = 80;

  //"Connect(%s:%d)\n", host, port;
  error = connectTcp(sock, host, port);
  //"connect: %d\n", error;
  if (error == 0) {
    StrPrint(line, "GET %s HTTP/1.1\r\n", path);
    sendString(sock, line, 0);
    StrPrint(line, "Host: %s\r\n", host);
    sendString(sock, line, 0);
    sendString(sock, "\r\n", 0);

    Bool haveHTTP = FALSE;
    Bool haveContentLength = FALSE;

    while (1) {
      error = recvLine(sock, line, sizeof(line), 0);

      if (error < 0) {
        break;
      }
      else if (error == 0) {
        if (!haveContentLength)
          error = HTTP_EPROTOCOL;
        break;
      }

      //"%s\n", line;
      if (!haveHTTP) {
        U8* code = StrFirstOcc(line, " ");
        if (code && StrNCmp(line, "HTTP/", 5) == 0 && StrNCmp(code + 1, "200", 3) == 0) {
          haveHTTP = TRUE;
        }
        else {
          error = HTTP_EREQUEST;
          break;
        }
      }
      else {
        U8* delim = StrFirstOcc(line, ":");

        if (!delim) {
          error = HTTP_EPROTOCOL;
          break;
        }

        *delim = 0;

        do { delim++; }
        while (*delim == ' ');

        //"%s=%s\n", line, delim;
        if (!StrCmp(line, "Content-Length")) {
          StrScan(delim, "%d", len_out);
          haveContentLength = TRUE;
        }
      }
    }
  }
  else
    error = HTTP_ECONNECT;

  if (error) {
    close(sock);
    return error;
  }
  else
    return sock;
}

I64 HttpGet(U8* host, U16 port = 0, U8* path, U8** data_out = NULL, I64* len_out = NULL) {
  I64 len = 0;
  I64 sock = HttpOpenGet(host, port, path, &len);

  if (sock < 0)
    return sock;

  if (data_out) {
    U8* data = MAlloc(1 + len);
    I64 got = recvall(sock, data, len, 0);
    close(sock);

    if (got >= 0)
      data[got] = 0;
    else
      data[0] = 0;

    if (got != len) {
      Free(data);
      *data_out = 0;
      return -1;
    }

    *data_out = data;
  }
  else {
    close(sock);
  }

  if (len_out)
    *len_out = len;

  return 0;
}
