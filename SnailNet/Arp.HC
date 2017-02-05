// vim: set ft=c:

// Not a Network Layer protocol, but it is encapsulated in L2 frames, which makes it L3 for our purposes

#define ARP_REQUEST         0x01
#define ARP_REPLY           0x02

class CArpHeader {
  U16 htype;
  U16 ptype;
  U8 hlen;
  U8 plen;
  U16 oper;
  U8 sha[6];
  U32 spa;
  U8 tha[6];
  U32 tpa;
};

class CArpCacheEntry {
  CArpCacheEntry* next;
  U32 ip;
  U8 mac[6];
};

// Stored in network order
static U32 arp_my_ipv4_n = 0;

// TODO: use a Hash table
static CArpCacheEntry* arp_cache = NULL;

// IPs are in network order
I64 ArpSend(U16 oper, U8* dest_mac, U8* sender_mac, U32 sender_ip_n, U8* target_mac, U32 target_ip_n) {
  U8* frame;

  I64 index = EthernetFrameAlloc(&frame, sender_mac, dest_mac,
      ETHERTYPE_ARP, sizeof(CArpHeader), 0);

  if (index < 0)
    return index;

  CArpHeader* hdr = frame;
  hdr->htype = htons(1);
  hdr->ptype = htons(ETHERTYPE_IPV4);
  hdr->hlen = 6;
  hdr->plen = 4;
  hdr->oper = htons(oper);
  MemCpy(hdr->sha, sender_mac, 6);
  hdr->spa = sender_ip_n;
  MemCpy(hdr->tha, target_mac, 6);
  hdr->tpa = target_ip_n;

  return EthernetFrameFinish(index);
}

U0 ArpSetIPv4Address(U32 addr) {
  arp_my_ipv4_n = htonl(addr);

  // Broadcast our new address
  ArpSend(ARP_REPLY, eth_broadcast, EthernetGetAddress(), arp_my_ipv4_n, eth_null, arp_my_ipv4_n);
}

CArpCacheEntry* ArpCacheFindByIP(U32 ip) {
  CArpCacheEntry* e = arp_cache;

  while (e) {
    if (e->ip == ip)
      return e;
    e = e->next;
  }

  return e;
}

CArpCacheEntry* ArpCachePut(U32 ip, U8* mac) {
  CArpCacheEntry* e = ArpCacheFindByIP(ip);

  if (!e) {
    //"ARP: add entry for %08X\n", ip;
    e = MAlloc(sizeof(CArpCacheEntry));
    e->next = arp_cache;
    e->ip = ip;
    MemCpy(e->mac, mac, 6);
    arp_cache = e;
  }
  // FIXME: else replace!

  return e;
}

I64 ArpHandler(CEthFrame* eth_frame) {
  if (eth_frame->ethertype != ETHERTYPE_ARP)
    return -1;

  if (eth_frame->length < sizeof(CArpHeader))
    return -1;

  CArpHeader* hdr = eth_frame->data;
  U16 oper = ntohs(hdr->oper);

  //"ARP: htype %d, ptype %d, hlen %d, plen %d, oper %d\n",
  //    ntohs(hdr->htype), ntohs(hdr->ptype), hdr->hlen, hdr->plen, oper;
  //"    spa %08X, tpa %08X\n", ntohl(hdr->spa), ntohl(hdr->tpa);

  if (ntohs(hdr->htype) != 1 || ntohs(hdr->ptype) != ETHERTYPE_IPV4
      || hdr->hlen != 6 || hdr->plen != 4)
    return -1;

  if (oper == ARP_REQUEST) {
    // Not too sure about this line, but it seems necessary in WiFi networks,
    // because the wireless device won't hear our Ethernet broadcast when we Request
    //ArpCachePut(ntohl(hdr->spa), hdr->sha);

    if (hdr->tpa == arp_my_ipv4_n) {
      ArpSend(ARP_REPLY, hdr->sha, EthernetGetAddress(), arp_my_ipv4_n, hdr->sha, hdr->spa);
    }
  }
  else if (oper == ARP_REPLY) {
    ArpCachePut(ntohl(hdr->spa), hdr->sha);
  }

  return 0;
}

RegisterL3Protocol(ETHERTYPE_ARP, &ArpHandler);
