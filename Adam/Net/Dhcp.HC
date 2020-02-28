// vim: set ft=c:

#include "::/Adam/Net/Socket"

#define BOOTREQUEST             0x01
#define BOOTREPLY               0x02

#define HTYPE_ETHERNET          0x01

#define HLEN_ETHERNET           6

#define DHCP_OPTION_SUBNET_MASK   1
#define DHCP_OPTION_ROUTER        3
#define DHCP_OPTION_DNS           6
#define DHCP_OPTION_DOMAIN_NAME   15
#define DHCP_OPTION_REQUESTED_IP  50
#define DHCP_OPTION_MSGTYPE       53
#define DHCP_OPTION_SERVER_ID     54
#define DHCP_OPTION_PARAMLIST     55

#define DHCP_COOKIE             0x63825363
#define DHCP_MSGTYPE_DISCOVER   0x01
#define DHCP_MSGTYPE_OFFER      0x02
#define DHCP_MSGTYPE_REQUEST    0x03
#define DHCP_MSGTYPE_ACK        0x05

class CDhcpHeader {
  U8 op;
  U8 htype;
  U8 hlen;
  U8 hops;
  U32 xid;
  U16 secs;
  U16 flags;
  U32 ciaddr;
  U32 yiaddr;
  U32 siaddr;
  U32 giaddr;
  U8 chaddr[16];
  U8 sname[64];
  U8 file[128];
};

class CDhcpDiscoverOptions {
  U32 cookie;
  // DHCP Message Type
  U8 dmt_type;
  U8 dmt_length;
  U8 dmt;
  // DHCP Parameter Request List
  U8 prl_type;
  U8 prl_length;
  U8 prl[4];

  U8 end;
};

class CDhcpRequestOptions {
  U32 cookie;
  // DHCP Message Type
  U8 dmt_type;
  U8 dmt_length;
  U8 dmt;
  // DHCP Requested IP
  U8 requested_ip_type;
  U8 requested_ip_length;
  U32 requested_ip;
  // DHCP Server Identifier
  U8 server_id_type;
  U8 server_id_length;
  U32 server_id;

  U8 end;
};

U32 DhcpBeginTransaction() {
  return RandU32();
}

I64 DhcpSendDiscover(U32 xid) {
  U8* frame;
  I64 index = UdpPacketAlloc(&frame, 0x00000000, 68, 0xffffffff, 67,
      sizeof(CDhcpHeader) + sizeof(CDhcpDiscoverOptions));

  if (index < 0)
    return index;

  CDhcpHeader* dhcp = frame;
  MemSet(dhcp, 0, sizeof(CDhcpHeader));
  dhcp->op = BOOTREQUEST;
  dhcp->htype = HTYPE_ETHERNET;
  dhcp->hlen = HLEN_ETHERNET;
  dhcp->hops = 0;
  dhcp->xid = htonl(xid);
  dhcp->secs = 0;
  dhcp->flags = htons(0x8000);
  dhcp->ciaddr = 0;
  dhcp->yiaddr = 0;
  dhcp->siaddr = 0;
  dhcp->giaddr = 0;
  MemCpy(dhcp->chaddr, EthernetGetAddress(), 6);

  CDhcpDiscoverOptions* opts = frame + sizeof(CDhcpHeader);
  opts->cookie = htonl(DHCP_COOKIE);
  opts->dmt_type = DHCP_OPTION_MSGTYPE;
  opts->dmt_length = 1;
  opts->dmt = DHCP_MSGTYPE_DISCOVER;
  opts->prl_type = DHCP_OPTION_PARAMLIST;
  opts->prl_length = 4;
  opts->prl[0] = DHCP_OPTION_SUBNET_MASK;
  opts->prl[1] = DHCP_OPTION_ROUTER;
  opts->prl[2] = DHCP_OPTION_DNS;
  opts->prl[3] = DHCP_OPTION_DOMAIN_NAME;
  opts->end = 0xff;

  return UdpPacketFinish(index);
}

I64 DhcpSendRequest(U32 xid, U32 requested_ip, U32 siaddr) {
  U8* frame;
  I64 index = UdpPacketAlloc(&frame, 0x00000000, 68, 0xffffffff, 67,
      sizeof(CDhcpHeader) + sizeof(CDhcpRequestOptions));

  if (index < 0)
    return index;

  CDhcpHeader* dhcp = frame;
  MemSet(dhcp, 0, sizeof(CDhcpHeader));
  dhcp->op = BOOTREQUEST;
  dhcp->htype = HTYPE_ETHERNET;
  dhcp->hlen = HLEN_ETHERNET;
  dhcp->hops = 0;
  dhcp->xid = htonl(xid);
  dhcp->secs = 0;
  dhcp->flags = htons(0x0000);
  dhcp->ciaddr = 0;
  dhcp->yiaddr = 0;
  dhcp->siaddr = htonl(siaddr);
  dhcp->giaddr = 0;
  MemCpy(dhcp->chaddr, EthernetGetAddress(), 6);

  CDhcpRequestOptions* opts = frame + sizeof(CDhcpHeader);
  opts->cookie = htonl(DHCP_COOKIE);
  opts->dmt_type = DHCP_OPTION_MSGTYPE;
  opts->dmt_length = 1;
  opts->dmt = DHCP_MSGTYPE_REQUEST;
  opts->requested_ip_type = DHCP_OPTION_REQUESTED_IP;
  opts->requested_ip_length = 4;
  opts->requested_ip = htonl(requested_ip);
  opts->server_id_type = DHCP_OPTION_SERVER_ID;
  opts->server_id_length = 4;
  opts->server_id = htonl(siaddr);
  opts->end = 0xff;

  return UdpPacketFinish(index);
}

I64 DhcpParseBegin(U8** data_inout, I64* length_inout, CDhcpHeader** hdr_out) {
  U8* data = *data_inout;
  I64 length = *length_inout;

  if (length < sizeof(CDhcpHeader) + 4) {
    //"DhcpParseBegin: too short\n";
    return -1;
  }

  U32* p_cookie = data + sizeof(CDhcpHeader);

  if (ntohl(*p_cookie) != DHCP_COOKIE) {
    //"DhcpParseBegin: cookie %08Xh != %08Xh\n", ntohl(*p_cookie), DHCP_COOKIE;
    return -1;
  }

  *hdr_out = data;
  *data_inout = data + (sizeof(CDhcpHeader) + 4);
  *length_inout = length - (sizeof(CDhcpHeader) + 4);
  return 0;
}

I64 DhcpParseOption(U8** data_inout, I64* length_inout, U8* type_out, U8* value_length_out, U8** value_out) {
  U8* data = *data_inout;
  I64 length = *length_inout;

  if (length < 2 || length < 2 + data[1]) {
    //"DhcpParseOption: too short\n";
    return -1;
  }

  if (data[0] == 0xff)
    return 0;

  *type_out = data[0];
  *value_length_out = data[1];
  *value_out = data + 2;

  *data_inout = data + (2 + *value_length_out);
  *length_inout = length - (2 + *value_length_out);
  return data[0];
}

I64 DhcpParseOffer(U32 xid, U8* data, I64 length, U32* yiaddr_out,
    U32* dns_ip_out, U32* router_ip_out, U32* subnet_mask_out) {
  CDhcpHeader* hdr;
  I64 error = DhcpParseBegin(&data, &length, &hdr);
  if (error < 0) return error;

  if (ntohl(hdr->xid) != xid)
    return -1;

  Bool have_type = FALSE;
  Bool have_dns = FALSE;
  Bool have_router = FALSE;
  Bool have_subnet = FALSE;

  while (length) {
    U8 type, value_length;
    U8* value;

    error = DhcpParseOption(&data, &length, &type, &value_length, &value);
    //"%d, %02Xh, %d, %02Xh...\n", error, type, value_length, value[0];
    if (error < 0) return error;
    if (error == 0) break;

    if (type == DHCP_OPTION_MSGTYPE && value_length == 1 && value[0] == DHCP_MSGTYPE_OFFER)
      have_type = TRUE;

    if (type == DHCP_OPTION_DNS && value_length == 4) {
      *dns_ip_out = ntohl(*(value(U32*)));
      have_dns = TRUE;
    }

    if (type == DHCP_OPTION_ROUTER && value_length == 4) {
      *router_ip_out = ntohl(*(value(U32*)));
      have_router = TRUE;
    }

    if (type == DHCP_OPTION_SUBNET_MASK && value_length == 4) {
      *subnet_mask_out = ntohl(*(value(U32*)));
      have_subnet = TRUE;
    }
  }

  //"DhcpParseOffer: end %d %d %d %d\n", have_type, have_dns, have_subnet, have_router;

  if (have_type && have_dns && have_subnet && have_router) {
    *yiaddr_out = ntohl(hdr->yiaddr);
    return 0;
  }
  else
    return -1;
}

I64 DhcpParseAck(U32 xid, U8* data, I64 length) {
  CDhcpHeader* hdr;
  I64 error = DhcpParseBegin(&data, &length, &hdr);
  if (error < 0) return error;

  if (ntohl(hdr->xid) != xid)
    return -1;

  while (length) {
    U8 type, value_length;
    U8* value;

    error = DhcpParseOption(&data, &length, &type, &value_length, &value);
    //"%d, %02Xh, %d, %02Xh...\n", error, type, value_length, value[0];
    if (error < 0) return error;
    if (error == 0) break;

    if (type == DHCP_OPTION_MSGTYPE && value_length == 1 && value[0] == DHCP_MSGTYPE_ACK)
      return 0;
  }

  return -1;
}
