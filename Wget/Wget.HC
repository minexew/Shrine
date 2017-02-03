// vim: set ft=cpp:

#include "::/Adam/Net/Url"
#include "::/Adam/Net/Http"

I64 Wget(U8* url, U8* saveas = NULL) {
  SocketInit();

  CUrl curl;
  UrlInit(&curl);

  I64 error = 0;

  if (UrlParse(url, &curl)) {
    //"wget,%s,%s,%d,%s\n", curl.protocol, curl.host, curl.port, curl.path;
    U8* data = NULL;
    I64 len = 0;

    error = HttpGet(curl.host, curl.port, curl.path, &data, &len);
    if (error == 0) {
      if (saveas) {
        FileWrite(saveas, data, len);
      }
      else {
        "%s\n", data;
      }
    }
    else {
      "$FG,4$Http error %d\n$FG$", error;
    }

    Free(data);
  }
  else {
    "$FG,4$Failed to parse URL$FG$\n";
    error = -1;
  }

  UrlFree(&curl);

  return error;
}
