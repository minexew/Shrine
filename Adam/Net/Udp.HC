// vim: set ft=c:

class CUdpHeader {
  U16 source_port;
  U16 dest_port;
  U16 length;
  U16 checksum;
};

class CUdpSocket {
  CSocket sock;

  I64 rcvtimeo_ms;
  I64 recv_maxtime;

  U8* recv_buf;
  I64 recv_len;

  sockaddr_in recv_addr;
  U16 bound_to;
};

// TODO: this takes up half a meg, change it to a binary tree or something
static CUdpSocket** udp_bound_sockets;

I64 UdpPacketAlloc(U8** frame_out, U32 source_ip, U16 source_port, U32 dest_ip, U16 dest_port, I64 length) {
  U8* frame;
  I64 index = IPv4PacketAlloc(&frame, IP_PROTO_UDP, source_ip, dest_ip, sizeof(CUdpHeader) + length);

  if (index < 0)
    return index;

  CUdpHeader* hdr = frame;
  hdr->source_port = htons(source_port);
  hdr->dest_port = htons(dest_port);
  hdr->length = htons(sizeof(CUdpHeader) + length);
  hdr->checksum = 0;

  *frame_out = frame + sizeof(CUdpHeader);
  return index;
}

I64 UdpPacketFinish(I64 index) {
  return IPv4PacketFinish(index);
}

I64 UdpParsePacket(U16* source_port_out, U16* dest_port_out, U8** data_out, I64* length_out, CIPv4Packet* packet) {
  if (packet->proto != IP_PROTO_UDP)
    return -1;

  CUdpHeader* hdr = packet->data;
  //"UDP: from %d, to %d, len %d, chksum %d\n",
  //    ntohs(hdr->source_port), ntohs(hdr->dest_port), ntohs(hdr->length), ntohs(hdr->checksum);

  // FIXME: validate packet->length

  *source_port_out = ntohs(hdr->source_port);
  *dest_port_out = ntohs(hdr->dest_port);
  //ntohs(hdr->length)
  //ntohs(hdr->checksum)

  *data_out = packet->data + sizeof(CUdpHeader);
  *length_out = packet->length - sizeof(CUdpHeader);

  return 0;
}

I64 UdpSocketAccept(CUdpSocket* s, sockaddr* addr, I64 addrlen) {
  no_warn s;
  no_warn addr;
  no_warn addrlen;
  return -1;
}

I64 UdpSocketBind(CUdpSocket* s, sockaddr* addr, I64 addrlen) {
  if (addrlen < sizeof(sockaddr_in))
    return -1;

  if (s->bound_to)
    return -1;

  sockaddr_in* addr_in = addr;
  U16 port = ntohs(addr_in->sin_port);

  // TODO: address & stuff
  if (udp_bound_sockets[port] != NULL)
    return -1;

  udp_bound_sockets[port] = s;
  s->bound_to = port;
  return 0;
}

I64 UdpSocketClose(CUdpSocket* s) {
  if (s->bound_to)
    udp_bound_sockets[s->bound_to] = NULL;

  Free(s);
  return 0;
}

I64 UdpSocketConnect(CUdpSocket* s, sockaddr* addr, I64 addrlen) {
  // FIXME: implement
  no_warn s;
  no_warn addr;
  no_warn addrlen;
  return -1;
}

I64 UdpSocketListen(CUdpSocket* s, I64 backlog) {
  no_warn s;
  no_warn backlog;
  return -1;
}

I64 UdpSocketRecvfrom(CUdpSocket* s, U8* buf, I64 len, I64 flags, sockaddr* src_addr, I64 addrlen) {
  no_warn flags;

  s->recv_buf = buf;
  s->recv_len = len;

  if (s->rcvtimeo_ms != 0)
    s->recv_maxtime = cnts.jiffies + s->rcvtimeo_ms * JIFFY_FREQ / 1000;

  while (s->recv_buf != NULL) {
    // Check for timeout
    if (s->rcvtimeo_ms != 0 && cnts.jiffies > s->recv_maxtime) {
      // TODO: seterror(EWOULDBLOCK)
      s->recv_len = -1;
      break;
    }

    Yield;
  }

  // TODO: addrlen
  if (src_addr) {
    // wtf? can't copy structs with '='?
    MemCpy((src_addr(sockaddr_in*)), &s->recv_addr, addrlen);
  }

  return s->recv_len;
}

I64 UdpSocketSendto(CSocket* s, U8* buf, I64 len, I64 flags, sockaddr_in* dest_addr, I64 addrlen) {
  no_warn s;
  no_warn flags;

  if (addrlen < sizeof(sockaddr_in))
    return -1;

  U8* frame;

  I64 index = UdpPacketAlloc(&frame, IPv4GetAddress(), 0, ntohl(dest_addr->sin_addr.s_addr),
      ntohs(dest_addr->sin_port), len);

  if (index < 0)
    return -1;

  MemCpy(frame, buf, len);
  return UdpPacketFinish(index);
}

I64 UdpSocketSetsockopt(CUdpSocket* s, I64 level, I64 optname, U8* optval, I64 optlen) {
  if (level == SOL_SOCKET && optname == SO_RCVTIMEO_MS && optlen == 8) {
    s->rcvtimeo_ms = *(optval(I64*));
    return 0;
  }

  return -1;
}

CUdpSocket* UdpSocket(U16 domain, U16 type) {
  if (domain != AF_INET || type != SOCK_DGRAM)
    return NULL;

  CUdpSocket* s =       MAlloc(sizeof(CUdpSocket));
  s->sock.accept =      &UdpSocketAccept;
  s->sock.bind =        &UdpSocketBind;
  s->sock.close =       &UdpSocketClose;
  s->sock.connect =     &UdpSocketConnect;
  s->sock.listen =      &UdpSocketListen;
  s->sock.recvfrom =    &UdpSocketRecvfrom;
  s->sock.sendto =      &UdpSocketSendto;
  s->sock.setsockopt =  &UdpSocketSetsockopt;

  s->rcvtimeo_ms = 0;
  s->recv_maxtime = 0;

  s->recv_buf = NULL;
  s->recv_len = 0;
  s->recv_addr.sin_family = AF_INET;
  s->bound_to = 0;
  return s;
}

I64 UdpHandler(CIPv4Packet* packet) {
  U16 source_port;
  U16 dest_port;
  U8* data;
  I64 length;

  I64 error = UdpParsePacket(&source_port, &dest_port, &data, &length, packet);

  if (error < 0)
    return error;

  //"%u => %p\n", dest_port, udp_bound_sockets[dest_port];

  CUdpSocket* s = udp_bound_sockets[dest_port];

  // FIXME: should also check that bound address is INADDR_ANY,
  //        OR packet dest IP matches bound address
  if (s != NULL) {
    if (s->recv_buf) {
      I64 num_recv = s->recv_len;

      if (num_recv > length)
        num_recv = length;

      MemCpy(s->recv_buf, data, num_recv);

      // signal that we received something
      s->recv_buf = NULL;
      s->recv_len = num_recv;

      // TODO: we keep converting n>h>n, fuck that
      s->recv_addr.sin_port = htons(source_port);
      s->recv_addr.sin_addr.s_addr = htonl(packet->source_ip);
    }
  }

  return error;
}

U0 UdpInit() {
  udp_bound_sockets = MAlloc(65536 * sizeof(CUdpSocket*));
  MemSet(udp_bound_sockets, 0, 65536 * sizeof(CUdpSocket*));
}

UdpInit;
RegisterL4Protocol(IP_PROTO_UDP, &UdpHandler);
RegisterSocketClass(AF_INET, SOCK_DGRAM, &UdpSocket);
