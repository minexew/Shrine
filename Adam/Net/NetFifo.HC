// Warning: terrible code ahead. this still needs a lot of work

// In the future we'll probably have 2 FIFOs (pending frames & empty buffers)
// TODO: check if FIFO implementation is suitable for high throughput

#define NET_FIFO_DEPTH      1024

#define ETHERNET_FRAME_SIZE 1548

#define ETHERTYPE_IPV4      0x0800
#define ETHERTYPE_ARP       0x0806

class CNetFifoEntry {
    I64 length;
    U8  frame[ETHERNET_FRAME_SIZE];
};

static CFifoI64* netfifo;

static CNetFifoEntry* entries;
static I64 next_entry = 0;

CTask* netfifo_handler_task = NULL;

// TODO: asm optimization? or perhaps use EndianU*?
// These don't belong here in the first place,
// but it's convenient for Ethernet drivers
// We'll probably split it off along with ETHERTYPE_* constants

U16 htons(U16 h) {
    return ((h >> 8) | (h << 8)) & 0xffff;
}

U16 ntohs(U16 h) {
    return ((h >> 8) | (h << 8)) & 0xffff;
}

U32 htonl(U32 h) {
    return ((h >> 24) | ((h & 0x00ff0000) >> 8) | ((h & 0x0000ff00) << 8) | (h << 24)) & 0xffffffff;
}

U32 ntohl(U32 h) {
    return ((h >> 24) | ((h & 0x00ff0000) >> 8) | ((h & 0x0000ff00) << 8) | (h << 24)) & 0xffffffff;
}

CNetFifoEntry* NetFifoPull() {
    CNetFifoEntry* entry;

    if (FifoI64Rem(netfifo, &entry))
        return entry;
    else
        return NULL;
}

I64 NetFifoPushCopy(U8* data, I64 length) {
    CNetFifoEntry* entry = &entries[next_entry];
    next_entry = (next_entry + 1) & (NET_FIFO_DEPTH - 1);

    entry->length = length;
    MemCpy(entry->frame, data, length);

    if (!FifoI64Ins(netfifo, entry))
        return -1;

    // Wake up Handler Task
    if (netfifo_handler_task)
        LBtr(&netfifo_handler_task->task_flags, TASKf_IDLE);

    return 0;
}

U0 NetFifoInit() {
    netfifo = FifoI64New(NET_FIFO_DEPTH);
    entries = MAlloc(NET_FIFO_DEPTH * sizeof(CNetFifoEntry));
}

NetFifoInit;
