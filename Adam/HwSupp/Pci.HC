// vim: set ft=c:

#define PCI_REG_VENDOR_ID           0x00
#define PCI_REG_DEVICE_ID           0x02
#define PCI_REG_COMMAND             0x04
#define PCI_REG_STATUS              0x06
#define PCI_REG_REVISION_ID         0x08
#define PCI_REG_PROG_IF             0x09
#define PCI_REG_SUBCLASS            0x0a
#define PCI_REG_CLASS               0x0b
#define PCI_REG_CACHE_LINE_SIZE     0x0c
#define PCI_REG_LATENCY_TIMER       0x0d
#define PCI_REG_HEADER_TYPE         0x0e
#define PCI_REG_BIST                0x0f
#define PCI_REG_BAR0                0x10
#define PCI_REG_BAR1                0x14
#define PCI_REG_BAR2                0x18
#define PCI_REG_BAR3                0x1c
#define PCI_REG_BAR4                0x20
#define PCI_REG_BAR5                0x24

#define PCI_REG_INTERRUPT_LINE      0x3C

class CPciDevInfo {
  U16 vendor_id, device_id;
  U16 command, status;
  U8 class_, subclass, prog_if, revision_id;
  U8 cache_line_size, latency_timer, header_type, bist;
  U32 bar[6];

  // ...a lot of trash comes here...

  U8 interrupt_line;
};

U0 PciDumpInfo(CPciDevInfo* info) {
  I64 i;

  "vendor_id=%04Xh\tdevice_id=%04Xh\n", info->vendor_id, info->device_id;
  "command=%04Xh\tstatus=%04Xh\n", info->command, info->status;
  "revision_id=%02Xh\tprog_if=%02Xh\n", info->revision_id, info->prog_if;
  "subclass=%02Xh\tclass_=%02Xh\n", info->subclass, info->class_;
  "cache_line_size=%02Xh\tlatency_timer=%02Xh\n", info->cache_line_size, info->latency_timer;
  "header_type=%02Xh\tbist=%02Xh\n", info->header_type, info->bist;

  for (i = 0; i < 6; i++)
    "BAR[%d]=%08X\n", i, info->bar[i];

  "interrupt_line=%02Xh\n", info->interrupt_line;
}

Bool PciFindByID(U16 vendor_id, U16 device_id, I64* bus_out, I64* dev_out, I64* fun_out) {
  I64 vendor, b, d, f, timeout = 32 * 8 * 2;

  if (dev.pci_head.next != &dev.pci_head)
    return FALSE;

  for (b = 0; b < sys_pci_busses; b++) {
    for (d = 0; d < 32; d++) {
      for (f = 0; f < 8; f++) {
        vendor = PCIReadU16(b, d, f, PCI_REG_VENDOR_ID);

        if (vendor != 0xFFFF) {
          if (vendor == vendor_id && PCIReadU16(b, d, f, PCI_REG_DEVICE_ID) == device_id) {
            *bus_out = b;
            *dev_out = d;
            *fun_out = f;
            return TRUE;
          }
          timeout = 32 * 8 * 2;
        }
        else if (sys_pci_busses == 256 && --timeout <= 0) {
          break;
        }
      }
    }
  }

  return FALSE;
}

U0 PciGetDevInfo(CPciDevInfo* info_out, I64 bus, I64 dev, I64 fun) {
  // TODO: do a bunch of PCIReadU32 in a loop instead
  info_out->vendor_id =       PCIReadU16(bus, dev, fun, PCI_REG_VENDOR_ID);
  info_out->device_id =       PCIReadU16(bus, dev, fun, PCI_REG_DEVICE_ID);
  info_out->command =         PCIReadU16(bus, dev, fun, PCI_REG_COMMAND);
  info_out->status =          PCIReadU16(bus, dev, fun, PCI_REG_STATUS);
  info_out->revision_id =     PCIReadU8(bus, dev, fun, PCI_REG_REVISION_ID);
  info_out->prog_if =         PCIReadU8(bus, dev, fun, PCI_REG_PROG_IF);
  info_out->subclass =        PCIReadU8(bus, dev, fun, PCI_REG_SUBCLASS);
  info_out->class_ =          PCIReadU8(bus, dev, fun, PCI_REG_CLASS);
  info_out->cache_line_size = PCIReadU8(bus, dev, fun, PCI_REG_CACHE_LINE_SIZE);
  info_out->latency_timer =   PCIReadU8(bus, dev, fun, PCI_REG_LATENCY_TIMER);
  info_out->header_type =     PCIReadU8(bus, dev, fun, PCI_REG_HEADER_TYPE);
  info_out->bist =            PCIReadU8(bus, dev, fun, PCI_REG_BIST);
  info_out->bar[0] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR0);
  info_out->bar[1] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR1);
  info_out->bar[2] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR2);
  info_out->bar[3] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR3);
  info_out->bar[4] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR4);
  info_out->bar[5] =          PCIReadU32(bus, dev, fun, PCI_REG_BAR5);

  info_out->interrupt_line =  PCIReadU8(bus, dev, fun, PCI_REG_INTERRUPT_LINE);
}

#define INT_DEST_CPU 0

U0 PciRerouteInterrupts(I64 base) {
  I64 i;
  U8* da = dev.uncached_alias + IOAPIC_REG;
  U32* _d = dev.uncached_alias + IOAPIC_DATA;

  for (i = 0; i < 4; i++) {
    *da = IOREDTAB + i * 2 + 1;
    *_d = dev.mp_apic_ids[INT_DEST_CPU] << 24;
    *da = IOREDTAB + i * 2;
    *_d = 0x4000 + base + i;
  }
}
