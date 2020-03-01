#define ICMP_TYPE_ECHO_REPLY      0
#define ICMP_TYPE_ECHO_REQUEST    8

class CIcmpHeader {
  U8 type;
  U8 code;
  U16 checksum;
  U16 identifier;
  U16 seq_number;
};

U64 *icmp_reply = CAlloc(sizeof(U64) * 65536);

U16 IcmpComputeChecksum(U8 *buf, I64 size)
{
  I64 i;
  U64 sum = 0;

  for (i=0; i<size; i += 2)
  {
    sum += *buf(U16*);
    buf += 2;
  }
  if (size - i > 0)
  {
    sum += *buf;
  }

  while ((sum>>16) != 0)
  {
    sum = (sum & 0xFFFF) + (sum >> 16);
  }

  return ~sum(U16);
}

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

I64 IcmpSendRequest(U32 dest_ip, U16 identifier, U16 seq_number, U16 request_checksum, U8* payload, I64 length) {
  U8* frame;
  I64 index = IPv4PacketAlloc(&frame, IP_PROTO_ICMP, IPv4GetAddress(), dest_ip, sizeof(CIcmpHeader) + length);

  if (index < 0)
    return index;

  CIcmpHeader* hdr = frame;
  hdr->type = ICMP_TYPE_ECHO_REQUEST;
  hdr->code = 0;
  hdr->checksum = 0;
  hdr->identifier = identifier;
  hdr->seq_number = seq_number;

  hdr->checksum = IcmpComputeChecksum(hdr, sizeof(CIcmpHeader));

  MemCpy(frame + sizeof(CIcmpHeader), payload, length);
  return IPv4PacketFinish(index);
}

I64 IcmpHandler(CIPv4Packet* packet) {
  if (packet->proto != IP_PROTO_ICMP)
    return -1;

  if (packet->length < sizeof(CIcmpHeader))
    return -1;

  CIcmpHeader* hdr = packet->data;

  if (hdr->type == ICMP_TYPE_ECHO_REPLY && hdr->code == 0) {
    icmp_reply[hdr->identifier] = packet;
  }

  if (hdr->type == ICMP_TYPE_ECHO_REQUEST && hdr->code == 0) {
    // This also makes sure that we don't stall NetHandlerTask
    ArpCachePut(packet->source_ip, packet->l2_frame->source_addr);

    IcmpSendReply(packet->source_ip, hdr->identifier, hdr->seq_number, hdr->checksum,
        packet->data + sizeof(CIcmpHeader), packet->length - sizeof(CIcmpHeader));
  }

  return 0;
}

RegisterL4Protocol(IP_PROTO_ICMP, &IcmpHandler);
