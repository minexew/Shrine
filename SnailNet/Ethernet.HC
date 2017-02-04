// vim: set ft=c:

class CEthFrame {
  U8  source_addr[6];
  U8  padding[2];
  U8  dest_addr[6];
  U16 ethertype;

  U8* data;
  I64 length;
};

class CL3Protocol {
  CL3Protocol* next;

  U16 ethertype;
  U8  padding[6];

  I64 (*handler)(CEthFrame* frame);
};

static CL3Protocol* l3_protocols = NULL;

U8 eth_null[6] = {0, 0, 0, 0, 0, 0};
U8 eth_broadcast[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};

I64 EthernetFrameParse(CEthFrame* frame_out, U8* frame, U16 length) {
    // FIXME: check length
    // TODO: MemCpy has high overhead, get rid of it
    MemCpy(frame_out->dest_addr, frame, 6);
    MemCpy(frame_out->source_addr, frame + 6, 6);
    frame_out->ethertype = frame[13] | (frame[12] << 8);

    /*"Rx dst: %02X:%02X:%02X:%02X:%02X:%02X\n",
            frame_out->dest_addr[0], frame_out->dest_addr[1], frame_out->dest_addr[2], frame_out->dest_addr[3], frame_out->dest_addr[4], frame_out->dest_addr[5];

    "Rx src: %02X:%02X:%02X:%02X:%02X:%02X\n",
            frame_out->source_addr[0], frame_out->source_addr[1], frame_out->source_addr[2], frame_out->source_addr[3], frame_out->source_addr[4], frame_out->source_addr[5];

    "Rx ethertype: %02X\n", frame_out->ethertype;*/

    frame_out->data = frame + 14;
    frame_out->length = length - 14 - 4;      // ??
    return 0;
}

U0 RegisterL3Protocol(U16 ethertype, I64 (*handler)(CEthFrame* frame)) {
  CL3Protocol* p = MAlloc(sizeof(CL3Protocol));

  p->next = l3_protocols;
  p->ethertype = ethertype;
  p->handler = handler;

  l3_protocols = p;
}
