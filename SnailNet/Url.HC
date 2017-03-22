// vim: set ft=cpp:

#include "::/Adam/Net/Http"

I64 UrlGet(U8* url, U8** data_out = NULL, I64* size_out = NULL) {
  CUrl curl;
  UrlInit(&curl);

  I64 error = 0;

  if (UrlParse(url, &curl)) {
    if (!StrCmp(curl.protocol, "http"))
      error = HttpGet(curl.host, curl.port, curl.path, data_out, size_out);
    else
      error = URL_EPROTOCOL;
  }
  else
    error = URL_EPARSE;

  UrlFree(&curl);
  return error;
}

I64 UrlGetWithProgress(U8* url, U8** data_out, I64* size_out) {
  CUrl curl;
  UrlInit(&curl);

  I64 error = 0;
  I64 size = 0;

  if (UrlParse(url, &curl)) {
    if (!StrCmp(curl.protocol, "http")) {
      I64 sock = HttpOpenGet(curl.host, curl.port, curl.path, &size);

      if (sock > 0) {
        if (size >= 0) {
          U8* data = MAlloc(1 + size);
          I64 total = 0;
          I64 progress = 0;
          "[$FG,3$";

          while (total < size) {
            I64 step = size - total;

            if (step > 1024)
              step = 1024;

            I64 got = recv(sock, data + total, step, 0);

            if (got <= 0) {
              error = HTTP_EEOF;
              break;
            }

            total += got;

            I64 new_progress = (20 * total + size - 1) / size;
            while (progress < new_progress) {
              '' 0xfe;
              progress++;
            }
          }
        }
        else
          error = HTTP_ECONTENTLENGTH;

        close(sock);

        if (error) {
          "$FG,4$x\n$FG$";
          Free(data);
        }
        else {
          "$FG$]\n";
          data[total] = 0;
          *data_out = data;
          *size_out = total;
        }
      }
      else
        error = sock;
    }
    else
      error = URL_EPROTOCOL;
  }
  else
    error = URL_EPARSE;

  UrlFree(&curl);
  return error;
}
