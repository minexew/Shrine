// vim: set ft=c:

#define DNS_RCODE_NO_ERROR        0
#define DNS_RCODE_FORMAT_ERROR    1
#define DNS_RCODE_SERVER_FAILURE  2
#define DNS_RCODE_NAME_ERROR      3
#define DNS_RCODE_NOT_IMPLEMENTED 5
#define DNS_RCODE_REFUSED         6

#define DNS_FLAG_RA         0x0080
#define DNS_FLAG_RD         0x0100
#define DNS_FLAG_TC         0x0200
#define DNS_FLAG_AA         0x0400

#define DNS_OP_QUERY        0
#define DNS_OP_IQUERY       1
#define DNS_OP_STATUS       2

#define DNS_FLAG_QR         0x8000

// http://www.freesoft.org/CIE/RFC/1035/14.htm
#define DNS_TYPE_A          1
#define DNS_TYPE_NS         2
#define DNS_TYPE_CNAME      5
#define DNS_TYPE_PTR        12
#define DNS_TYPE_MX         15
#define DNS_TYPE_TXT        16

// http://www.freesoft.org/CIE/RFC/1035/16.htm
#define DNS_CLASS_IN        1

#define DNS_TIMEOUT         5000
#define DNS_MAX_RETRIES     3

class CDnsCacheEntry {
  CDnsCacheEntry* next;
  U8* hostname;
  addrinfo info;
  // TODO: honor TTL
};

class CDnsHeader {
  U16 id;
  U16 flags;
  U16 qdcount;
  U16 ancount;
  U16 nscount;
  U16 arcount;
};

class CDnsDomainName {
  U8** labels;
  I64 num_labels;
}

class CDnsQuestion {
  CDnsQuestion* next;

  CDnsDomainName qname;
  U16 qtype;
  U16 qclass;
};

class CDnsRR {
  CDnsRR* next;

  CDnsDomainName name;
  U16 type;
  U16 class_;
  U32 ttl;
  U16 rdlength;
  U8* rdata;
};

// TODO: use a Hash table
static CDnsCacheEntry* dns_cache = NULL;

static U32 dns_ip = 0;

static CDnsCacheEntry* DnsCacheFind(U8* hostname) {
  CDnsCacheEntry* e = dns_cache;

  while (e) {
    if (!StrCmp(e->hostname, hostname))
      return e;

    e = e->next;
  }

  return e;
}

static CDnsCacheEntry* DnsCachePut(U8* hostname, addrinfo* info) {
  CDnsCacheEntry* e = DnsCacheFind(hostname);

  if (!e) {
    e = MAlloc(sizeof(CDnsCacheEntry));
    e->next = dns_cache;
    e->hostname = StrNew(hostname);
    AddrInfoCopy(&e->info, info);

    dns_cache = e;
  }

  return e;
}

static I64 DnsCalcQuestionSize(CDnsQuestion* question) {
  I64 size = 0;
  I64 i;
  for (i = 0; i < question->qname.num_labels; i++) {
    size += 1 + StrLen(question->qname.labels[i]);
  }
  return size + 1 + 4;
}

static U0 DnsSerializeQuestion(U8* buf, CDnsQuestion* question) {
  I64 i;

  for (i = 0; i < question->qname.num_labels; i++) {
    U8* label = question->qname.labels[i];
    *(buf++) = StrLen(label);

    while (*label)
      *(buf++) = *(label++);
  }

  *(buf++) = 0;
  *(buf++) = (question->qtype >> 8);
  *(buf++) = (question->qtype & 0xff);
  *(buf++) = (question->qclass >> 8);
  *(buf++) = (question->qclass & 0xff);
}

static I64 DnsSendQuestion(U16 id, U16 local_port, CDnsQuestion* question) {
  if (!dns_ip)
    return -1;

  U8* frame;
  I64 index = UdpPacketAlloc(&frame, IPv4GetAddress(), local_port, dns_ip, 53,
      sizeof(CDnsHeader) + DnsCalcQuestionSize(question));

  if (index < 0)
    return index;

  U16 flags = (DNS_OP_QUERY << 11) | DNS_FLAG_RD;

  CDnsHeader* hdr = frame;
  hdr->id = htons(id);
  hdr->flags = htons(flags);
  hdr->qdcount = htons(1);
  hdr->ancount = 0;
  hdr->nscount = 0;
  hdr->arcount = 0;

  DnsSerializeQuestion(frame + sizeof(CDnsHeader), question);

  return UdpPacketFinish(index);
}

static I64 DnsParseDomainName(U8* packet_data, I64 packet_length,
    U8** data_inout, I64* length_inout, CDnsDomainName* name_out) {
  U8* data = *data_inout;
  I64 length = *length_inout;
  Bool jump_taken = FALSE;

  if (length < 1) {
    //"DnsParseDomainName: EOF\n";
    return -1;
  }

  name_out->labels = MAlloc(16 * sizeof(U8*));
  name_out->num_labels = 0;

  U8* name_buf = MAlloc(256);
  name_out->labels[0] = name_buf;

  while (length) {
    I64 label_len = *(data++);
    length--;

    if (label_len == 0) {
      break;
    }
    else if (label_len >= 192) {
      label_len &= 0x3f;

      if (!jump_taken) {
        *data_inout = data + 1;
        *length_inout = length - 1;
        jump_taken = TRUE;
      }

      //"jmp %d\n", ((label_len << 8) | *data);

      data = packet_data + ((label_len << 8) | *data);
      length = packet_data + packet_length - data;
    }
    else {
      if (length < label_len) return -1;

      MemCpy(name_buf, data, label_len);
      data += label_len;
      length -= label_len;

      name_buf[label_len] = 0;
      //"%d bytes => %s\n", label_len, name_buf;
      name_out->labels[name_out->num_labels++] = name_buf;

      name_buf += label_len + 1;
    }
  }

  if (!jump_taken) {
    *data_inout = data;
    *length_inout = length;
  }

  return 0;
}

static I64 DnsParseQuestion(U8* packet_data, I64 packet_length,
    U8** data_inout, I64* length_inout, CDnsQuestion* question_out) {
  I64 error = DnsParseDomainName(packet_data, packet_length,
      data_inout, length_inout, &question_out->qname);

  if (error < 0)
    return error;

  U8* data = *data_inout;
  I64 length = *length_inout;

  if (length < 4)
    return -1;

  question_out->next = NULL;
  question_out->qtype = (data[1] << 8) | data[0];
  question_out->qclass = (data[3] << 8) | data[2];

  //"DnsParseQuestion: qtype %d, qclass %d\n", ntohs(question_out->qtype), ntohs(question_out->qclass);

  *data_inout = data + 4;
  *length_inout = length - 4;
  return 0;
}

static I64 DnsParseRR(U8* packet_data, I64 packet_length,
    U8** data_inout, I64* length_inout, CDnsRR* rr_out) {
  I64 error = DnsParseDomainName(packet_data, packet_length,
      data_inout, length_inout, &rr_out->name);

  if (error < 0)
    return error;

  U8* data = *data_inout;
  I64 length = *length_inout;

  if (length < 10)
    return -1;

  rr_out->next = NULL;
  MemCpy(&rr_out->type, data, 10);

  I64 record_length = 10 + ntohs(rr_out->rdlength);

  if (length < record_length)
    return -1;

  rr_out->rdata = data + 10;

  //"DnsParseRR: type %d, class %d\n, ttl %d, rdlength %d\n",
  //    ntohs(rr_out->type), ntohs(rr_out->class_), ntohl(rr_out->ttl), ntohs(rr_out->rdlength);

  *data_inout = data + record_length;
  *length_inout = length - record_length;
  return 0;
}

static I64 DnsParseResponse(U16 id, U8* data, I64 length,
    CDnsHeader** hdr_out, CDnsQuestion** questions_out,
    CDnsRR** answers_out) {
  U8* packet_data = data;
  I64 packet_length = length;

  if (length < sizeof(CDnsHeader)) {
    //"DnsParseResponse: too short\n";
    return -1;
  }

  CDnsHeader* hdr = data;
  data += sizeof(CDnsHeader);

  if (id != 0 && ntohs(hdr->id) != id) {
    //"DnsParseResponse: id %04Xh != %04Xh\n", ntohs(hdr->id), id;
    return -1;
  }

  I64 i;

  for (i = 0; i < htons(hdr->qdcount); i++) {
    CDnsQuestion* question = MAlloc(sizeof(CDnsQuestion));
    if (DnsParseQuestion(packet_data, packet_length, &data, &length, question) < 0)
      return -1;

    question->next = *questions_out;
    *questions_out = question;
  }

  for (i = 0; i < htons(hdr->ancount); i++) {
    CDnsRR* answer = MAlloc(sizeof(CDnsRR));
    if (DnsParseRR(packet_data, packet_length, &data, &length, answer) < 0)
      return -1;

    answer->next = *answers_out;
    *answers_out = answer;
  }

  *hdr_out = hdr;
  return 0;
}

static U0 DnsBuildQuestion(CDnsQuestion* question, U8* name) {
  question->next = NULL;
  question->qname.labels = MAlloc(16 * sizeof(U8*));
  question->qname.labels[0] = 0;
  question->qname.num_labels = 0;
  question->qtype = DNS_TYPE_A;
  question->qclass = DNS_CLASS_IN;

  U8* copy = StrNew(name);

  while (*copy) {
    question->qname.labels[question->qname.num_labels++] = copy;
    U8* dot = StrFirstOcc(copy, ".");

    if (dot) {
      *dot = 0;
      copy = dot + 1;
    }
    else
      break;
  }
}

static U0 DnsFreeQuestion(CDnsQuestion* question) {
  Free(question->qname.labels[0]);
}

static U0 DnsFreeRR(CDnsRR* rr) {
  Free(rr->name.labels[0]);
}

static U0 DnsFreeQuestionChain(CDnsQuestion* questions) {
  while (questions) {
    CDnsQuestion* next = questions->next;
    DnsFreeQuestion(questions);
    Free(questions);
    questions = next;
  }
}

static U0 DnsFreeRRChain(CDnsRR* rrs) {
  while (rrs) {
    CDnsQuestion* next = rrs->next;
    DnsFreeRR(rrs);
    Free(rrs);
    rrs = next;
  }
}

static I64 DnsRunQuery(I64 sock, U8* name, U16 port, addrinfo** res_out) {
  I64 retries = 0;
  I64 timeout = DNS_TIMEOUT;

  if (setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO_MS, &timeout, sizeof(timeout)) < 0) {
    "$FG,6$DnsRunQuery: setsockopt failed\n$FG$";
  }

  U16 local_port = RandU16();

  sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(local_port);
  addr.sin_addr.s_addr = INADDR_ANY;

  if (bind(sock, &addr, sizeof(addr)) < 0) {
    "$FG,4$DnsRunQuery: failed to bind\n$FG$";
    return -1;
  }

  U8 buffer[2048];

  I64 count;
  sockaddr_in addr_in;

  U16 id = RandU16();
  I64 error = 0;

  CDnsQuestion question;
  DnsBuildQuestion(&question, name);

  while (1) {
    error = DnsSendQuestion(id, local_port, &question);
    if (error < 0) return error;

    count = recvfrom(sock, buffer, sizeof(buffer), 0, &addr_in, sizeof(addr_in));

    if (count > 0) {
      //"Try parse response\n";
      CDnsHeader* hdr = NULL;
      CDnsQuestion* questions = NULL;
      CDnsRR* answers = NULL;

      error = DnsParseResponse(id, buffer, count, &hdr, &questions, &answers);

      if (error >= 0) {
        Bool have = FALSE;

        // Look for a suitable A-record in the answer
        CDnsRR* answer = answers;
        while (answer) {
          // TODO: if there are multiple acceptable answers,
          //       we should pick one at random -- not just the first one
          if (htons(answer->type) == DNS_TYPE_A
              && htons(answer->class_) == DNS_CLASS_IN
              && htons(answer->rdlength) == 4) {
            addrinfo* res = MAlloc(sizeof(addrinfo));
            res->ai_flags = 0;
            res->ai_family = AF_INET;
            res->ai_socktype = 0;
            res->ai_protocol = 0;
            res->ai_addrlen = sizeof(sockaddr_in);
            res->ai_addr = MAlloc(sizeof(sockaddr_in));
            res->ai_canonname = NULL;
            res->ai_next = NULL;

            sockaddr_in* sa = res->ai_addr;
            sa->sin_family = AF_INET;
            sa->sin_port = port;
            MemCpy(&sa->sin_addr.s_addr, answers->rdata, 4);

            DnsCachePut(name, res);
            *res_out = res;
            have = TRUE;
            break;
          }

          answer = answer->next;
        }

        DnsFreeQuestionChain(questions);
        DnsFreeRRChain(answers);

        if (have)
          break;

        // At this point we could try iterative resolution,
        // but all end-user DNS servers would have tried that already

        "$FG,6$DnsParseResponse: no suitable answer in reply\n$FG$";
        error = -1;
      }
      else {
        "$FG,6$DnsParseResponse: error %d\n$FG$", error;
      }
    }

    if (++retries == DNS_MAX_RETRIES) {
      "$FG,4$DnsRunQuery: max retries reached\n$FG$";
      error = -1;
      break;
    }
  }

  DnsFreeQuestion(&question);
  return error;
}

I64 DnsGetaddrinfo(U8* node, U8* service, addrinfo* hints, addrinfo** res) {
  no_warn service;
  no_warn hints;

  CDnsCacheEntry* cached = DnsCacheFind(node);

  if (cached) {
    *res = MAlloc(sizeof(addrinfo));
    AddrInfoCopy(*res, &cached->info);
    (*res)->ai_flags |= AI_CACHED;
    return 0;
  }

  I64 sock = socket(AF_INET, SOCK_DGRAM);
  I64 error = 0;

  if (sock >= 0) {
    // TODO: service should be parsed as int, specifying port number
    error = DnsRunQuery(sock, node, 0, res);

    close(sock);
  }
  else
    error = -1;

  return error;
}

U0 DnsSetResolverIPv4(U32 ip) {
  dns_ip = ip;
}

public U0 Host(U8* hostname) {
  addrinfo* res = NULL;
  I64 error = getaddrinfo(hostname, NULL, NULL, &res);

  if (error < 0) {
    "$FG,4$getaddrinfo: error %d\n", error;
  }
  else {
    addrinfo* curr = res;
    while (curr) {
      "flags %04Xh, family %d, socktype %d, proto %d, addrlen %d, addr %s\n",
          curr->ai_flags, curr->ai_family, curr->ai_socktype, curr->ai_protocol, curr->ai_addrlen,
          inet_ntoa((curr->ai_addr(sockaddr_in*))->sin_addr);
      curr = curr->ai_next;
    }
  }

  freeaddrinfo(res);
}

U0 DnsInit() {
  static CAddrResolver dns_addr_resolver;
  dns_addr_resolver.getaddrinfo = &DnsGetaddrinfo;

  socket_addr_resolver = &dns_addr_resolver;
}

DnsInit;
