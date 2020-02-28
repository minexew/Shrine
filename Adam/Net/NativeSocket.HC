// vim: set ft=c:

#define SOCK_STREAM     1
#define SOCK_DGRAM      2
#define SOCK_RAW        3

#define AF_UNSPEC       0
#define AF_INET         2
#define AF_INET6        10

#define INADDR_ANY      0

#define SOL_SOCKET      1

// optval = I64*
#define SO_RCVTIMEO_MS  1

#define AI_CACHED       0x8000

class in_addr {
  U32 s_addr;
};

class sockaddr {
  U16   sa_family;
  U8    sa_data[14];
};

class sockaddr_in {
  I16     sin_family;
  U16     sin_port;
  in_addr sin_addr;
  U8      sin_zero[8];
};

class addrinfo {
  I32       ai_flags;
  I32       ai_family;
  I32       ai_socktype;
  I32       ai_protocol;
  I64       ai_addrlen;
  sockaddr* ai_addr;
  U8*       ai_canonname;
  addrinfo* ai_next;
};

I64 inet_aton(U8* cp, in_addr* inp) {
  // FIXME: error handling
  I64 a, b, c, d;
  StrScan(cp, "%d.%d.%d.%d", &a, &b, &c, &d);
  inp->s_addr = (a | (b << 8) | (c << 16) | (d << 24));
  return 0;
}

U8* inet_ntoa(in_addr in) {
  static U8 buffer[16];
  StrPrint(buffer, "%d.%d.%d.%d", in.s_addr & 0xff, (in.s_addr >> 8) & 0xff,
      (in.s_addr >> 16) & 0xff, (in.s_addr >> 24) & 0xff);
  return buffer;
}

class CSocket {
  I64 (*accept)(CSocket* s, sockaddr* src_addr, I64 addrlen);
  I64 (*bind)(CSocket* s, sockaddr* addr, I64 addrlen);
  I64 (*close)(CSocket* s);
  I64 (*connect)(CSocket* s, sockaddr* addr, I64 addrlen);
  I64 (*listen)(CSocket* s, I64 backlog);
  I64 (*recvfrom)(CSocket* s, U8* buf, I64 len, I64 flags, sockaddr* src_addr, I64 addrlen);
  I64 (*sendto)(CSocket* s, U8* buf, I64 len, I64 flags, sockaddr* dest_addr, I64 addrlen);
  I64 (*setsockopt)(CSocket* s, I64 level, I64 optname, U8* optval, I64 optlen);
};

class CSocketClass {
  CSocketClass* next;

  U16 domain;
  U16 type;
  U8 padding[4];

  CSocket* (*socket)(U16 domain, U16 type);
};

class CAddrResolver {
  // TODO: allow different resolvers for different socket domains

  I64 (*getaddrinfo)(U8* node, U8* service, addrinfo* hints, addrinfo** res);
};

static CSocketClass* socket_classes = NULL;
static CAddrResolver* socket_addr_resolver = NULL;

static CSocketClass* FindSocketClass(U16 domain, U16 type) {
  CSocketClass* cls = socket_classes;

  while (cls) {
    if (cls->domain == domain && cls->type == type)
      return cls;

    cls = cls->next;
  }

  return NULL;
}

I64 SocketInit() {
  return 0;
}

I64 socket(I64 domain, I64 type) {
  CSocketClass* cls = FindSocketClass(domain, type);

  if (cls) return cls->socket(domain, type)(I64);
  else return -1;
}

I64 accept(I64 sockfd, sockaddr* addr, I64 addrlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->accept(sock, addr, addrlen);
  else return -1;
}

I64 close(I64 sockfd) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->close(sock);
  else return -1;
}

I64 bind(I64 sockfd, sockaddr* addr, I64 addrlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->bind(sock, addr, addrlen);
  else return -1;
}

I64 connect(I64 sockfd, sockaddr* addr, I64 addrlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->connect(sock, addr, addrlen);
  else return -1;
}

I64 listen(I64 sockfd, I64 backlog) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->listen(sock, backlog);
  else return -1;
}

I64 recv(I64 sockfd, U8* buf, I64 len, I64 flags) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->recvfrom(sock, buf, len, flags, NULL, 0);
  else return -1;
}

I64 recvfrom(I64 sockfd, U8* buf, I64 len, I64 flags, sockaddr* src_addr, I64 addrlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->recvfrom(sock, buf, len, flags, src_addr, addrlen);
  else return -1;
}

I64 send(I64 sockfd, U8* buf, I64 len, I64 flags) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->sendto(sock, buf, len, flags, NULL, 0);
  else return -1;
}

I64 sendto(I64 sockfd, U8* buf, I64 len, I64 flags, sockaddr* dest_addr, I64 addrlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->sendto(sock, buf, len, flags, dest_addr, addrlen);
  else return -1;
}

I64 setsockopt(I64 sockfd, I64 level, I64 optname, U8* optval, I64 optlen) {
  CSocket* sock = sockfd(CSocket*);
  if (sockfd > 0) return sock->setsockopt(sock, level, optname, optval, optlen);
  else return -1;
}

I64 getaddrinfo(U8* node, U8* service, addrinfo* hints, addrinfo** res) {
  if (socket_addr_resolver) return socket_addr_resolver->getaddrinfo(node, service, hints, res);
  else return -1;
}

U0 freeaddrinfo(addrinfo* res) {
  while (res) {
    addrinfo* next = res->ai_next;
    Free(res->ai_addr);
    Free(res->ai_canonname);
    Free(res);
    res = next;
  }
}

U0 AddrInfoCopy(addrinfo* ai_out, addrinfo* ai_in) {
  MemCpy(ai_out, ai_in, sizeof(addrinfo));

  if (ai_in->ai_addr) {
    ai_out->ai_addr = MAlloc(ai_in->ai_addrlen);
    MemCpy(ai_out->ai_addr, ai_in->ai_addr, ai_in->ai_addrlen);
  }

  if (ai_in->ai_canonname) {
    ai_out->ai_canonname = StrNew(ai_in->ai_canonname);
  }
}

U8* gai_strerror(I64 errcode) {
  no_warn errcode;
  return "Unspecified error";
}

// Inspired by https://docs.python.org/3.7/library/socket.html#socket.create_connection
I64 create_connection(U8* hostname, U16 port) {
  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = 0;

  addrinfo* res;
  I64 error = getaddrinfo(hostname, NULL, NULL, &res);

  if (error < 0) {
    "$FG,4$getaddrinfo: error %d\n$FG$", error;
  }
  else {
    addrinfo* curr = res;

    while (curr) {
      if (curr->ai_family == AF_INET && (curr->ai_socktype == 0 || curr->ai_socktype == SOCK_STREAM)) {
        addr.sin_addr.s_addr = (curr->ai_addr(sockaddr_in*))->sin_addr.s_addr;
        freeaddrinfo(res);

        I64 sockfd = socket(AF_INET, SOCK_STREAM);

        if (sockfd < 0)
          return sockfd;

        error = connect(sockfd, &addr, sizeof(addr));

        if (error < 0) {
          close(sockfd);
          return error;
        }

        return sockfd;
      }

      curr = curr->ai_next;
    }

    "$FG,4$create_connection: no suitable address\n$FG$";
  }

  freeaddrinfo(res);
  return -1;
}

U0 RegisterSocketClass(U16 domain, U16 type, CSocket* (*socket)(U16 domain, U16 type)) {
  CSocketClass* cls = MAlloc(sizeof(CSocketClass));

  cls->next = socket_classes;
  cls->domain = domain;
  cls->type = type;
  cls->socket = socket;

  socket_classes = cls;
}
