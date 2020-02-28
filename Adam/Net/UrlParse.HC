// vim: set ft=cpp:

#define URL_EPARSE    (-201)
#define URL_EPROTOCOL (-202)

class CUrl {
  U8* protocol;
  U8* host;
  U16 port;
  U8* path;
};

U0 UrlInit(CUrl* url) {
  url->protocol = 0;
  url->host = 0;
  url->port = 0;
  url->path = 0;
}

U0 UrlFree(CUrl* url) {
  Free(url->protocol);
  Free(url->host);
  Free(url->path);
  UrlInit(url);
}

Bool UrlParse(U8* url, CUrl* url_out) {
  U8* colon = StrFirstOcc(url, ":");
  U8* protosep = StrFind("//", url);

  if (colon && colon < protosep) {
    I64 len = colon - url;
    url_out->protocol = MAlloc(len + 1);
    MemCpy(url_out->protocol, url, len);
    url_out->protocol[len] = 0;

    url = colon + 1;
    while (*url == '/')
      url++;
  }
  else {
    url_out->protocol = StrNew("http");
  }

  I64 pos = 0;

  while (url[pos]) {
    if (url[pos] == ':' || url[pos] == '/') {
      url_out->host = MAlloc(pos + 1);
      MemCpy(url_out->host, url, pos);
      url_out->host[pos] = 0;

      if (url[pos] == ':') {
        I64 port = 0;
        U8* end = 0;
        port = Str2I64(url + pos + 1, 10, &end);

        url_out->port = port;
        url_out->path = StrNew(end);
      }
      else {
        url_out->path = StrNew(url + pos);
      }

      return TRUE;
    }

    pos++;
  }

  url_out->host = StrNew(url);
  return TRUE;
}
