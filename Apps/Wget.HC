#include "::/Adam/Net/Url"

I64 Wget(U8* url, U8* saveas = NULL) {
  SocketInit();

  U8* data;
  I64 len;
  I64 error = UrlGet(url, &data, &len);

  if (!error) {
    if (saveas) {
      FileWrite(saveas, data, len);
    }
    else {
      "%s\n", data;
    }
  }
  else {
    "$FG,4$Wget: error %d\n$FG$", error;
  }

  return error;
}
