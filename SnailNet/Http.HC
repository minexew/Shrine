// vim: set ft=cpp:

#include "::/Adam/Net/Socket"
#include "::/Adam/Net/UrlParse"

#define HTTP_ECONNECT   (-101)
#define HTTP_EPROTOCOL  (-102)
#define HTTP_EREQUEST   (-103)
#define HTTP_EREDIRECT  (-104)
#define HTTP_EEOF       (-105)
#define HTTP_ECONTENTLENGTH (-106)

#define HTTP_MAX_REDIRECTS  5
#define HTTP_USER_AGENT "SnailNet ($TX+CX,"TempleOS",D="DD_OS_NAME_VERSION"$)"

/**
 * @param len_out (required) requires the content length, or -1 if unspecified
 * @return socket (>= 0) on success, error code on failure
 */
I64 HttpOpenGet(U8* host, U16 port = 0, U8* path, I64* len_out,
    I64 allowed_redirects = HTTP_MAX_REDIRECTS) {
  U8 line[256];
  I64 error = 0;

  if (!port)
    port = 80;

  // Should this be done here though?
  if (*path == 0)
    path = "/";

  //"Connect(%s:%d)\n", host, port;
  I64 sock = create_connection(host, port);
  //"create_connection: %d\n", sock;
  if (sock >= 0) {
    StrPrint(line, "GET %s HTTP/1.0\r\n", path);
    sendString(sock, line, 0);
    StrPrint(line, "Host: %s\r\n", host);
    sendString(sock, line, 0);
    sendString(sock, "User-Agent: " HTTP_USER_AGENT "\r\n", 0);
    sendString(sock, "\r\n", 0);

    Bool haveHTTP = FALSE;
    U8* location = NULL;

    I64 code = -1;

    *len_out = -1;

    while (1) {
      error = recvLine(sock, line, sizeof(line), 0);

      if (error < 0) {
        break;
      }
      else if (error == 0) {
        if (!haveHTTP)
          error = HTTP_EPROTOCOL;
        break;
      }

      U8* delim;

      //"%s\n", line;
      if (!haveHTTP) {
        delim = StrFirstOcc(line, " ");
        if (delim && StrNCmp(line, "HTTP/", 5) == 0) {
          code = Str2I64(delim + 1);

          if (code >= 200 && code <= 399) {
            haveHTTP = TRUE;
          }
          else {
            error = HTTP_EREQUEST;
            break;
          }
        }
        else {
          error = HTTP_EREQUEST;
          break;
        }
      }
      else {
        delim = StrFirstOcc(line, ":");

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
        }
        else if (!StrCmp(line, "Location")) {
          // This will leak on malformed response
          location = StrNew(delim);
        }
      }
    }

    // HTTP Code 3xx -- Redirection
    if (!error && code >= 300 && code <= 399) {
      if (allowed_redirects > 0) {
        CUrl curl;
        UrlInit(&curl);

        if (UrlParse(location, &curl)) {
          if (!StrCmp(curl.protocol, "http")) {
            close(sock);
            sock = HttpOpenGet(curl.host, curl.port, curl.path, len_out, allowed_redirects - 1);

            if (sock < 0)
              error = sock;
          }
          else
            error = HTTP_EPROTOCOL;
        }
        else
          error = HTTP_EREDIRECT;

        UrlFree(&curl);
      }
      else {
        error = HTTP_EREDIRECT;
      }
    }

    Free(location);
  }
  else
    error = HTTP_ECONNECT;

  if (error) {
    close(sock);
    return error;
  }
  else {
    return sock;
  }
}

I64 HttpGet(U8* host, U16 port = 0, U8* path, U8** data_out = NULL, I64* len_out = NULL) {
  I64 len = 0;
  I64 sock = HttpOpenGet(host, port, path, &len);

  if (sock < 0)
    return sock;

  // We currently don't handle chunked encoding
  if (len < 0) {
    close(sock);
    return HTTP_ECONTENTLENGTH;
  }

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
