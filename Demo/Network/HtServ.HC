// See https://www.w3.org/Protocols/HTTP/1.0/spec.html

#include "::/Adam/Net/Socket"

#define PORT 80
#define BASE_DIR "/Www"

// Set to NULL if you don't want to print anything
#define HTTP_SERVER_STRING "Server: HtServ ($TX+CX,"TempleOS",D="DD_OS_NAME_VERSION"$)\r\n"

#define STATE_TERM 0
#define STATE_NEW 1
#define STATE_HEADERS 2

#define METHOD_GET 0

class CHtServSession {
  CTcpSocket* sock;
  U8 state;
  U8 method;

  U8* protocol;
  U8* resource;
};

// Messy global state!
U8* new_output;

U0 StreamPrint(U8 *fmt,...)
{//Injects text into the webpage stream. Used in <exe> tags.
  U8* buf = StrPrintJoin(NULL,fmt,argc,argv);
  U8* old_output = new_output;
  new_output = MStrPrint("%s%s", old_output, buf);
  Free(buf);
  Free(old_output);
}

Bool IsDotHTM(U8 *filename)
{//Does name end in .HTM?
  I64 len = StrLen(filename);
  if (len >= 4 && !StrNCmp(filename + len - 4, ".HTM", 4))
    return TRUE;
  else
    return FALSE;
}

U8* PreprocessHTM(U8* body) {
  new_output = StrNew("");
  U8* body_ptr = body;

  while (*body_ptr) {
    // Perhaps we should use something like <script type="text/x-holyc"> instead?
    U8* occ = StrFind("<exe>", body_ptr);

    if (occ) {
      // Add body to output, up to the <exe> tag
      *occ = 0;
      StreamPrint("%s", body_ptr);

      occ += 5;
      U8* end = StrFind("</exe>", occ);
      if (end) {
        *end = 0;
      }

      // We can also pass filename, but it is meaningless without correct line number
      ExePutS(occ);

      if (end)
        body_ptr = end + 6;
      else
        break;
    }
    else {
      // Add (rest of) body to output
      StreamPrint("%s", body_ptr);
      break;
    }
  }

  Free(body);
  return new_output;
}

U0 HtServProcess(CHtServSession* sess) {
  // look for resource
  // TODO: prevent access to parent
  U8* path = MStrPrint("%s/%s", BASE_DIR, sess->resource);
  I64 size;
  U8* data = FileRead(path, &size);   // FIXME: never freed?
  U8 line[256];

  if (data) {
    // If this is a .HTM file, we preprocess it first
    Bool is_htm = IsDotHTM(path);

    if (is_htm) {
      // We assume that data is NUL-terminated
      data = PreprocessHTM(data);
      size = StrLen(data);
    }

    // Send "200 OK"
    StrPrint(line, "%s 200 OK\r\n", sess->protocol); // FIXME possible overflow
    sendString(sess->sock, line, 0);
    StrPrint(line, "Content-Length: %d\r\n", size);
    sendString(sess->sock, line, 0);
    if (is_htm) {
      sendString(sess->sock, "Content-Type: text/html\r\n", 0);
    }
    if (HTTP_SERVER_STRING) {
      sendString(sess->sock, HTTP_SERVER_STRING, 0);
    }

    sendString(sess->sock, "\r\n", 0);
    sendall(sess->sock, data, size, 0);
    sess->state = STATE_TERM;
  }
  else {
    // Send "404 Not Found"
    StrPrint(line, "%s 404 Not Found\r\n", sess->protocol); // FIXME possible overflow
    sendString(sess->sock, line, 0);
    sendString(sess->sock, "Content-Length: 0\r\n", 0);
    if (HTTP_SERVER_STRING) {
      sendString(sess->sock, HTTP_SERVER_STRING, 0);
    }
    sendString(sess->sock, "\r\n", 0);
    sess->state = STATE_TERM;
  }
}

U0 HtServSession(CTcpSocket* sock) {
  DocNew;
  CHtServSession sess;
  sess.sock = sock;
  sess.state = STATE_NEW;

  "HtServ: session begin\n";
  // TODO: log peer addr

  while (sess.state != STATE_TERM) {
    U8 line[256];
    I64 error = recvLine(sock, line, sizeof(line), 0);

    if (error < 0) {
      break;
    }

    "REQUEST: %s\n", line;

    U8* delim;

    switch (sess.state) {
      case STATE_NEW:
        // expect "GET <resource> HTTP/1.x"
        delim = StrFirstOcc(line, " ");
        if (!delim) {
          // Malformed request, ignore
          sess.state = STATE_TERM; break;
        }

        *delim = 0;

        if (!StrCmp(line, "GET")) {
          sess.method = METHOD_GET;

          U8* resource = delim + 1;
          delim = StrFirstOcc(resource, " ");
          if (!delim) {
            // "HTTP 0.9", currently not supported
            sess.state = STATE_TERM; break;
          }

          *delim = 0;
          U8* protocol = delim + 1;
          if (StrCmp(protocol, "HTTP/1.0") != 0 && StrCmp(protocol, "HTTP/1.1")) {
            "HtServ: Bad protocol\n";
            // TODO: sent 400 Bad Request
            sess.state = STATE_TERM; break;
          }

          sess.protocol = StrNew(protocol);
          
          // FIXME: should urldecode resource
          // FIXME: must check for trailing slash in general
          if (!StrCmp(resource, "/")) {
            sess.resource = StrNew("/Index.HTM");
          }
          else {
            sess.resource = StrNew(resource);
          }

          sess.state = STATE_HEADERS;
        }
        else {
          "HtServ: Invalid method %s\n", line;
          // TODO: sent 400 Bad Request
        }
        break;

      case STATE_HEADERS:
        if (*line == 0) {
          "HtServ: headers done\n";
          HtServProcess(&sess);
          sess.state = STATE_TERM;
          break;
        }
        else {
          // Ignore all headers for now
        }
        break;
    }

    // send(client, buffer, count, 0);
  }

  close(sock);
}

I8 HtServ() {
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

  "$FG,2$Serving %s on port %d\n$FG$", BASE_DIR, PORT;

  while (1) {
    I64 client = accept(sock, 0, 0);
    if (client)
      Spawn(&HtServSession, client);
    else
      break;
    Yield; // loop unconditionally
  }
  close(sock);
  return 0;
}
