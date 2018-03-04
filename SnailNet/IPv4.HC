// vim: set ft=c:

#define IP_PROTO_ICMP           0x01
#define IP_PROTO_TCP            0x06
#define IP_PROTO_UDP            0x11

#define IPV4_EADDR_INVALID      (-200001)
#define IPV4_EHOST_UNREACHABLE  (-200002)

#define IPV4_TTL                64

class CIPv4Packet {
  CEthFrame* l2_frame;

  U32 source_ip;
  U32 dest_ip;
  U8  proto;
  U8  padding[7];

  U8* data;
  I64 length;
};

class CIPv4Header {
  U8 version_ihl;
  U8 dscp_ecn;
  U16 total_length;
  U16 ident;
  U16 flags_fragoff;
  U8 ttl;
  U8 proto;
  U16 header_checksum;
  U32 source_ip;
  U32 dest_ip;
};

class CL4Protocol {
  CL4Protocol* next;

  U8 proto;
  U8 padding[7];

  U0 (*handler)(CIPv4Packet* packet);
};

// *_n = stored in network order
static U32 my_ip = 0;
static U32 my_ip_n = 0;

static U32 ipv4_router_addr = 0;
static U32 ipv4_subnet_mask = 0;

static CL4Protocol* l4_protocols = NULL;

// http://stackoverflow.com/q/26774761/2524350
static U16 IPv4Checksum(U8* header, I64 length) {
  I64 nleft = length;
  U16* w = header;
  I64 sum = 0;

  while (nleft > 1)  {
    sum += *(w++);
    nleft -= 2;
  }

  // mop up an odd byte, if necessary
  if (nleft == 1) {
    sum += ((*w) & 0x00ff);
  }

  // add back carry outs from top 16 bits to low 16 bits
  sum = (sum >> 16) + (sum & 0xffff); // add hi 16 to low 16
  sum += (sum >> 16);         // add carry
  return (~sum) & 0xffff;
}

static I64 GetEthernetAddressForIP(U32 ip, U8** mac_out) {
  // invalid
  if (ip == 0) {
    return IPV4_EADDR_INVALID;
  }
  // broadcast
  else if (ip == 0xffffffff) {
    *mac_out = eth_broadcast;
    return 0;
  }
  // outside this subnet; needs routing
  else if ((ip & ipv4_subnet_mask) != (my_ip & ipv4_subnet_mask)) {
    // FIXME: infinite loop if mis-configured

    return GetEthernetAddressForIP(ipv4_router_addr, mac_out);
  }
  // local network
  else {
    // FIXME: this can stall NetHandlerTask, we might need a flag to bail early

    CArpCacheEntry* e = ArpCacheFindByIP(ip);

    if (e) {
      *mac_out = e->mac;
      return 0;
    }

    //"Not in cache, requesting\n";

    // Up to 4 retries, 500 ms each
    I64 retries = 4;

    while (retries) {
      ArpSend(ARP_REQUEST, eth_broadcast, EthernetGetAddress(), my_ip_n, eth_null, htonl(ip));

      I64 try_ = 0;

      for (try_ = 0; try_ < 50; try_++) {
        Sleep(10);

        e = ArpCacheFindByIP(ip);
        if (e) break;
      }

      if (e) {
        *mac_out = e->mac;
        return 0;
      }

      retries--;
    }

    in_addr in;
    in.s_addr = htonl(ip);
    "$FG,6$IPv4: Failed to resolve address %s\n$FG$", inet_ntoa(in);
    return IPV4_EHOST_UNREACHABLE;
  }
}

I64 IPv4PacketAlloc(U8** frame_out, U8 proto, U32 source_ip, U32 dest_ip, I64 length) {
  U8* frame;
  U8* dest_mac;

  I64 error = GetEthernetAddressForIP(dest_ip, &dest_mac);

  if (error < 0)
    return error;

  I64 index = EthernetFrameAlloc(&frame, EthernetGetAddress(), dest_mac,
      ETHERTYPE_IPV4, sizeof(CIPv4Header) + length, 0);

  if (index < 0)
    return index;

  I64 internet_header_length = 5;

  CIPv4Header* hdr = frame;
  hdr->version_ihl = internet_header_length | (4 << 4);
  hdr->dscp_ecn = 0;
  hdr->total_length = htons(internet_header_length * 4 + length);
  hdr->ident = 0;
  hdr->flags_fragoff = 0;
  hdr->ttl = IPV4_TTL;
  hdr->proto = proto;
  hdr->header_checksum = 0;
  hdr->source_ip = htonl(source_ip);
  hdr->dest_ip = htonl(dest_ip);

  hdr->header_checksum = IPv4Checksum(hdr, internet_header_length * 4);

  *frame_out = frame + sizeof(CIPv4Header);
  return index;
}

I64 IPv4PacketFinish(I64 index) {
  return EthernetFrameFinish(index);
}

U32 IPv4GetAddress() {
  return my_ip;
}

U0 IPv4SetAddress(U32 addr) {
  my_ip = addr;
  my_ip_n = htonl(addr);

  ArpSetIPv4Address(addr);
}

U0 IPv4SetSubnet(U32 router_addr, U32 subnet_mask) {
  ipv4_router_addr = router_addr;
  ipv4_subnet_mask = subnet_mask;
}

I64 IPv4ParsePacket(CIPv4Packet* packet_out, CEthFrame* eth_frame) {
  if (eth_frame->ethertype != ETHERTYPE_IPV4)
    return -1;

  // FIXME: check eth_frame->length etc.

  CIPv4Header* hdr = eth_frame->data;
  I64 header_length = (hdr->version_ihl & 0x0f) * 4;
  //"IPv4: hdr %d, proto %02X, source %08X, dest %08X, len %d\n",
  //    header_length, hdr->proto, ntohl(hdr->source_ip), ntohl(hdr->dest_ip),
  //    eth_frame->length - header_length;

  U16 total_length = ntohs(hdr->total_length);

  packet_out->l2_frame = eth_frame;
  packet_out->source_ip = ntohl(hdr->source_ip);
  packet_out->dest_ip = ntohl(hdr->dest_ip);
  packet_out->proto = hdr->proto;

  packet_out->data = eth_frame->data + header_length;
  packet_out->length = total_length - header_length;

  return 0;
}

U0 RegisterL4Protocol(U8 proto, I64 (*handler)(CIPv4Packet* frame)) {
  CL4Protocol* p = MAlloc(sizeof(CL4Protocol));

  p->next = l4_protocols;
  p->proto = proto;
  p->handler = handler;

  l4_protocols = p;
}

I64 IPv4Handler(CEthFrame* eth_frame) {
  CIPv4Packet packet;

  I64 error = IPv4ParsePacket(&packet, eth_frame);

  if (error < 0)
    return error;

  // This seems necessary to receive connections under VBox NAT,
  // but is also pretty slow, so should be optimized to use a better
  // struct than linked list.
  ArpCachePut(packet.source_ip, eth_frame->source_addr);

  CL4Protocol* l4 = l4_protocols;

  while (l4) {
    if (l4->proto == packet.proto) {
      l4->handler(&packet);
      break;
    }
    l4 = l4->next;
  }

  return error;
}

RegisterL3Protocol(ETHERTYPE_IPV4, &IPv4Handler);
