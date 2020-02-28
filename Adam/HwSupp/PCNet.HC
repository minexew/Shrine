// vim: set ft=c:

#include "::/Adam/HwSupp/Pci"

// Significantly based on http://wiki.osdev.org/AMD_PCNET

#define PCNET_DEVICE_ID         0x2000
#define PCNET_VENDOR_ID         0x1022

#define PCNET_COMMAND_IOEN      (1<<0)
#define PCNET_COMMAND_MEMEN     (1<<1)
#define PCNET_COMMAND_BMEN      (1<<2)
#define PCNET_COMMAND_SCYCEN    (1<<3)
#define PCNET_COMMAND_MWIEN     (1<<4)
#define PCNET_COMMAND_VGASNOOP  (1<<5)
#define PCNET_COMMAND_PERREN    (1<<6)
#define PCNET_COMMAND_ADSTEP    (1<<7)
#define PCNET_COMMAND_SERREN    (1<<8)
#define PCNET_COMMAND_FBTBEN    (1<<9)

#define PCNET_STATUS_FBTBC      (1<<7)
#define PCNET_STATUS_DATAPERR   (1<<8)
#define PCNET_STATUS_DEVSEL_BIT 9
#define PCNET_STATUS_STABORT    (1<<11)
#define PCNET_STATUS_RTABORT    (1<<12)
#define PCNET_STATUS_RMABORT    (1<<13)
#define PCNET_STATUS_SERR       (1<<14)
#define PCNET_STATUS_PERR       (1<<15)

#define PCNET_WD_RESET          0x14

#define PCNET_DW_RDP            0x10
#define PCNET_DW_RAP            0x14
#define PCNET_DW_RESET          0x18

#define PCNET_CSR0_INIT         (1<<0)
#define PCNET_CSR0_STRT         (1<<1)
#define PCNET_CSR0_STOP         (1<<2)
#define PCNET_CSR0_IENA         (1<<6)
#define PCNET_CSR0_IDON         (1<<8)
#define PCNET_CSR0_TINT         (1<<9)
#define PCNET_CSR0_RINT         (1<<10)

#define PCNET_CSR3_BSWP         (1<<2)
#define PCNET_CSR3_IDONM        (1<<8)
#define PCNET_CSR3_TINTM        (1<<9)
#define PCNET_CSR3_RINTM        (1<<10)

#define PCNET_CSR4_TXSTRT       (1<<3)
#define PCNET_CSR4_ASTRP_RCV    (1<<10)
#define PCNET_CSR4_APAD_XMT     (1<<11)

#define PCNET_TXFIFO_FULL       (-1)

// TODO: this should be configurable
#define PCNET_NUM_RX_LOG2   5
#define PCNET_NUM_TX_LOG2   3

#define rx_buffer_count (1<<PCNET_NUM_RX_LOG2)
#define tx_buffer_count (1<<PCNET_NUM_TX_LOG2)

// Including SrcAddr, DstAddr, EtherType
// Where does this even belong? NetFifo defines for now.
//#define ETHERNET_FRAME_SIZE     1548

#define PCNET_DE_SIZE 16

class CPCNetBufferSetup {
  U16 mode;
  U8 rlen;
  U8 tlen;
  U8 mac[6];
  U16 reserved;
  U8 ladr[8];
  U32 rxbuf;
  U32 txbuf;
};

// Card I/O base
I64 pcnet_iob = 0;

U8 my_mac[6];

// Current Rx/Tx buffer
I64 rx_buffer_ptr = 0;
I64 tx_buffer_ptr = 0;

// Rx/Tx descriptor ring buffers, PCNET_DE_SIZE each
// _phys are uncached
U8* rdes_phys;
U8* tdes_phys;
U8* rdes;
U8* tdes;

U32 rx_buffers;                   // physical address of actual receive buffers (< 4 GiB)
U32 tx_buffers;                   // physical address of actual transmit buffers (< 4 GiB)

static U0 writeRAP32(U32 val) {
  OutU32(pcnet_iob + PCNET_DW_RAP, val);
}

static U32 readCSR32(U32 csr_no) {
  writeRAP32(csr_no);
  return InU32(pcnet_iob + PCNET_DW_RDP);
}

static U0 writeCSR32(U32 csr_no, U32 val) {
  writeRAP32(csr_no);
  OutU32(pcnet_iob + PCNET_DW_RDP, val);
}

static U0 PCNetReset() {
  InU32(pcnet_iob + PCNET_DW_RESET);
  InU16(pcnet_iob + PCNET_WD_RESET);
}

// does the driver own the particular buffer?
static I64 driverOwns(U8 *des, I64 idx)
{
  return (des[PCNET_DE_SIZE * idx + 7] & 0x80) == 0;
}

static U0 PCNetReadEeprom(I64 offset, U8* buffer, I64 count) {
  while (count) {
    *buffer = InU32(pcnet_iob + offset);
    offset++;
    buffer++;
    count--;
  }
}

static I64 PCNetRxPacket(U8** buffer_out, U16* length_out) {
  I64 index = rx_buffer_ptr;

  // packet length is given by bytes 8 and 9 of the descriptor
  //  (no need to negate it unlike BCNT above)
  U16* p16 = &rdes[index * PCNET_DE_SIZE + 8];
  U16 length = *p16;

  // increment rx_buffer_ptr;
  rx_buffer_ptr = (rx_buffer_ptr + 1) & (rx_buffer_count - 1);

  *buffer_out = rx_buffers + index * ETHERNET_FRAME_SIZE;
  *length_out = length;
  return index;
}

static I64 PCNetReleaseRxPacket(I64 index) {
  rdes[index * PCNET_DE_SIZE + 7] = 0x80;

  return 0;
}

static I64 PCNetAllocTxPacket(U8** buffer_out, I64 length, I64 flags) {
  // FIXME: validate length
  flags = flags;

  if (!driverOwns(tdes, tx_buffer_ptr)) {
    return PCNET_TXFIFO_FULL;
  }

  I64 index = tx_buffer_ptr;

  // set the STP bit in the descriptor entry (signals this is the first
  //  frame in a split packet - we only support single frames)
  tdes[index * PCNET_DE_SIZE + 7] |= 0x2;
 
  // similarly, set the ENP bit to state this is also the end of a packet
  tdes[index * PCNET_DE_SIZE + 7] |= 0x1;
 
  // set the BCNT member to be 0xf000 OR'd with the first 12 bits of the
  //  two's complement of the length of the packet
  U16 bcnt = (-length);
  bcnt &= 0xfff;
  bcnt |= 0xf000;
  U16* p16 = &tdes[index * PCNET_DE_SIZE + 4];
  *p16 = bcnt;

  tx_buffer_ptr = (tx_buffer_ptr + 1) & (tx_buffer_count - 1);

  *buffer_out = tx_buffers + index * ETHERNET_FRAME_SIZE;
  return index;
}

static I64 PCNetFinishTxPacket(I64 index) {
  // finally, flip the ownership bit back to the card
  tdes[index * PCNET_DE_SIZE + 7] |= 0x80;

  return 0;
}

static U0 PCNetInitDE(U32 buf_addr, U8 *des, I64 idx, I64 is_tx) {
  MemSet(&des[idx * PCNET_DE_SIZE], PCNET_DE_SIZE, 0);

  // first 4 bytes are the physical address of the actual buffer
  U32* p32 = &des[idx * PCNET_DE_SIZE];
  *p32 = buf_addr + idx * ETHERNET_FRAME_SIZE;

  // next 2 bytes are 0xf000 OR'd with the first 12 bits of the 2s complement of the length
  U16 bcnt = (-ETHERNET_FRAME_SIZE);
  bcnt &= 0x0fff;
  bcnt |= 0xf000;

  U16* p16 = &des[idx * PCNET_DE_SIZE + 4];
  *p16 = bcnt;

  // finally, set ownership bit - transmit buffers are owned by us, receive buffers by the card
  if (!is_tx)
    des[idx * PCNET_DE_SIZE + 7] = 0x80;
}

static I64 PCNetAllocBuffers() {
  I64 i;

  I64 rdes_size = PCNET_DE_SIZE * rx_buffer_count;
  I64 tdes_size = PCNET_DE_SIZE * tx_buffer_count;

  rdes_phys = MAlloc(rdes_size, Fs->code_heap);
  tdes_phys = MAlloc(tdes_size, Fs->code_heap);

  if (rdes_phys + rdes_size > 0x100000000 || tdes_phys + tdes_size > 0x100000000) {
    "$FG,4$PCNetAllocBuffers: rdes_phys=%08Xh tdes_phys=%08Xh\n$FG$", rdes_phys, tdes_phys;
    return -1;
  }

  rdes = rdes_phys + dev.uncached_alias;
  tdes = tdes_phys + dev.uncached_alias;

  I64 rx_buffers_size = ETHERNET_FRAME_SIZE * rx_buffer_count;
  I64 tx_buffers_size = ETHERNET_FRAME_SIZE * tx_buffer_count;

  // TODO: shouldn't these be uncached as well?
  rx_buffers = MAlloc(rx_buffers_size, Fs->code_heap);
  tx_buffers = MAlloc(tx_buffers_size, Fs->code_heap);

  if (rx_buffers + rx_buffers_size > 0x100000000 || tx_buffers + tx_buffers_size > 0x100000000) {
    "$FG,4$PCNetAllocBuffers: rx_buffers=%08Xh tx_buffers=%08Xh\n$FG$", rx_buffers, tx_buffers;
    return -1;
  }

  for (i = 0; i < rx_buffer_count; i++)
    PCNetInitDE(rx_buffers, rdes, i, FALSE);

  for (i = 0; i < tx_buffer_count; i++)
    PCNetInitDE(tx_buffers, tdes, i, TRUE);

  //"rdes: %08Xh\ttdes: %08X\n", rdes, tdes;
  //"rbuf: %08Xh\ttbuf: %08X\n", rx_buffers, tx_buffers;

  return 0;
}

interrupt U0 PCNetIrq() {
  U32 csr0 = readCSR32(0);

  while (driverOwns(rdes, rx_buffer_ptr)) {
  //if (csr0 & PCNET_CSR0_RINT) {
    //"Int reason %08X\n", csr0;

    U8* buffer;
    U16 length;
    I64 index = PCNetRxPacket(&buffer, &length);

    if (index >= 0) {
      //"[%d] Rx %d B\n", index, length;
      NetFifoPushCopy(buffer, length);
      PCNetReleaseRxPacket(index);
    }

    writeCSR32(0, csr0 | PCNET_CSR0_RINT);
  }

  *(dev.uncached_alias + LAPIC_EOI)(U32*) = 0;
}

static U0 PCNetInit(I64 bus, I64 dev_, I64 fun) {
  CPciDevInfo info;

  PciGetDevInfo(&info, bus, dev_, fun);
  //PciDumpInfo(&info);

  if (info.vendor_id != PCNET_VENDOR_ID || info.device_id != PCNET_DEVICE_ID)
    throw;

  U16 config = PCNET_COMMAND_IOEN | PCNET_COMMAND_BMEN;
  PCIWriteU16(bus, dev_, fun, PCI_REG_COMMAND, config);

  config = PCIReadU16(bus, dev_, fun, PCI_REG_COMMAND);

  pcnet_iob = (PCIReadU32(bus, dev_, fun, PCI_REG_BAR0) & ~(0x0000001f));
  //U32 membase = (PCIReadU32(bus, dev_, fun, PCI_REG_BAR1) & ~(0x0000001f));
  //"PCNet iobase: %016Xh\n", pcnet_iob;
  //"PCNet membase: %08Xh\n", membase;

  // Reset the card to get into defined state
  PCNetReset();
  Sleep(1);

  // Enter 32-bit mode
  OutU32(pcnet_iob + PCNET_DW_RDP, 0);

  // SWSTYLE
  U32 csr58 = readCSR32(58);
  csr58 &= 0xfff0;
  csr58 |= 2;
  writeCSR32(58, csr58);

  PCNetReadEeprom(0, my_mac, 6);

  if (PCNetAllocBuffers() < 0)
    return;

  U8* setup = MAlloc(sizeof(CPCNetBufferSetup), Fs->code_heap);
  CPCNetBufferSetup* u_setup = setup + dev.uncached_alias;

  u_setup->mode = 0;     // see CSR15 in spec
  u_setup->rlen = (PCNET_NUM_RX_LOG2 << 4);
  u_setup->tlen = (PCNET_NUM_TX_LOG2 << 4);
  MemCpy(u_setup->mac, my_mac, 6);
  "PCNet MAC: %02X:%02X:%02X:%02X:%02X:%02X\n",
      u_setup->mac[0], u_setup->mac[1], u_setup->mac[2], u_setup->mac[3], u_setup->mac[4], u_setup->mac[5];
  u_setup->reserved = 0;
  MemSet(u_setup->ladr, 0, 8);
  u_setup->rxbuf = rdes_phys;
  u_setup->txbuf = tdes_phys;

  U32 p_setup = setup;
  writeCSR32(1, p_setup & 0xffff);
  writeCSR32(2, p_setup >> 16);

  U32 csr3 = readCSR32(3);
  csr3 &= ~PCNET_CSR3_BSWP;       // disable big-endian
  csr3 &= ~PCNET_CSR3_RINTM;      // enable Rx interruot
  csr3 |= PCNET_CSR3_IDONM;       // mask-out Init Done Interrupt
  csr3 |= PCNET_CSR3_TINTM;       // mask-out Tx interrupt
  writeCSR32(3, csr3);

  U32 csr4 = readCSR32(4);
  csr4 |= PCNET_CSR4_APAD_XMT;    // auto pad transmit
  writeCSR32(4, csr4);

  // Upload configuration
  writeCSR32(0, readCSR32(0) | PCNET_CSR0_INIT | PCNET_CSR0_IENA);

  while (!(readCSR32(0) & PCNET_CSR0_IDON)) {
    Yield;
  }

  // Exit config mode
  U32 csr0 = readCSR32(0);
  csr0 &= ~(PCNET_CSR0_INIT | PCNET_CSR0_STOP);
  csr0 |= PCNET_CSR0_STRT;
  writeCSR32(0, csr0);

  // Init interrupt
  //IntEntrySet(info.interrupt_line, &PCNetIrq, IDTET_IRQ);
  IntEntrySet(0x40, &PCNetIrq, IDTET_IRQ);
  IntEntrySet(0x41, &PCNetIrq, IDTET_IRQ);
  IntEntrySet(0x42, &PCNetIrq, IDTET_IRQ);
  IntEntrySet(0x43, &PCNetIrq, IDTET_IRQ);
  PciRerouteInterrupts(0x40);

  Sleep(100);

  Free(setup);
}

I64 EthernetFrameAlloc(U8** buffer_out, U8* src_addr, U8* dst_addr, U16 ethertype, I64 length, I64 flags) {
  U8* frame;

  // APAD_XMT doesn't seem to work in VirtualBox, so we have to pad the frame ourselves
  if (length < 46)
    length = 46;

  I64 index = PCNetAllocTxPacket(&frame, 14 + length, flags);

  if (index < 0)
    return index;

  MemCpy(frame + 0, dst_addr, 6);
  MemCpy(frame + 6, src_addr, 6);
  frame[12] = (ethertype >> 8);
  frame[13] = (ethertype & 0xff);

  *buffer_out = frame + 14;
  return index;
}

I64 EthernetFrameFinish(I64 index) {
  return PCNetFinishTxPacket(index);
}

U8* EthernetGetAddress() {
  return my_mac;
}

I64 EthernetInit() {
  I64 b, d, f;

  if (pcnet_iob != 0)
    return 0;

  if (PciFindByID(PCNET_VENDOR_ID, PCNET_DEVICE_ID, &b, &d, &f)) {
    //"PCNet @ %d:%d:%d\n", b, d, f;
    PCNetInit(b, d, f);
    return 0;
  }

  return -1;
}
