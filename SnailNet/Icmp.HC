// vim: set ft=c:

#define ICMP_TYPE_ECHO_REPLY      0
#define ICMP_TYPE_ECHO_REQUEST    8

class CIcmpHeader {
  U8 type;
  U8 code;
  U16 checksum;
  U16 identifier;
  U16 seq_number;
};

I64 IcmpSendReply(U32 dest_ip, U16 identifier, U16 seq_number, U16 request_checksum, U8* payload, I64 length) {
  U8* frame;
  I64 index = IPv4PacketAlloc(&frame, IP_PROTO_ICMP, IPv4GetAddress(), dest_ip, sizeof(CIcmpHeader) + length);

  if (index < 0)
    return index;

  CIcmpHeader* hdr = frame;
  hdr->type = ICMP_TYPE_ECHO_REPLY;
  hdr->code = 0;
  hdr->checksum = htons(ntohs(request_checksum) + 0x0800);    // hack alert!
  hdr->identifier = identifier;
  hdr->seq_number = seq_number;

  MemCpy(frame + sizeof(CIcmpHeader), payload, length);
  return IPv4PacketFinish(index);
}

I64 IcmpHandler(CIPv4Packet* packet) {
  if (packet->proto != IP_PROTO_ICMP)
    return -1;

  if (packet->length < sizeof(CIcmpHeader))
    return -1;

  CIcmpHeader* hdr = packet->data;

  if (hdr->type == ICMP_TYPE_ECHO_REQUEST && hdr->code == 0) {
    // This also makes sure that we don't stall NetHandlerTask
    ArpCachePut(packet->source_ip, packet->l2_frame->source_addr);

    IcmpSendReply(packet->source_ip, hdr->identifier, hdr->seq_number, hdr->checksum,
        packet->data + sizeof(CIcmpHeader), packet->length - sizeof(CIcmpHeader));
  }

  return 0;
}

RegisterL4Protocol(IP_PROTO_ICMP, &IcmpHandler);
