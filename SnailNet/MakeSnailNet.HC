// vim: set ft=c:

#exe {
  #include "::/Adam/HwSupp/Pci"

  U8* native_driver = NULL;
  I64 b, d, f;

  if (PciFindByID(0x1022, 0x2000, &b, &d, &f))
    native_driver = "PCNet";

  // If we're using the native stack, load it system-wide
  if (native_driver != NULL) {
    StreamPrint("U8* SNAILNET_NATIVE_DRIVER = \"%s\";\n", native_driver);

    // Hardware support
    StreamPrint("#include \"::/Adam/Net/NetFifo\"");
    StreamPrint("#include \"::/Adam/HwSupp/%s\"", native_driver);

    // Contains a lot of common definitions, probably should be cleaned up
    StreamPrint("#include \"::/Adam/Net/NativeSocket\"");

    // L2
    StreamPrint("#include \"::/Adam/Net/Ethernet\"");

    // L3
    StreamPrint("#include \"::/Adam/Net/Arp\"");
    StreamPrint("#include \"::/Adam/Net/IPv4\"");

    // L4
    StreamPrint("#include \"::/Adam/Net/Icmp\"");
    StreamPrint("#include \"::/Adam/Net/Tcp\"");
    StreamPrint("#include \"::/Adam/Net/Udp\"");

    // L7
    StreamPrint("#include \"::/Adam/Net/Dns\"");

    // Handler Task
    StreamPrint("#include \"::/Adam/Net/NetHandlerTask\"");

    StreamPrint("#include \"::/Adam/Net/Netcfg\"");
  }
  else
    StreamPrint("U8* SNAILNET_NATIVE_DRIVER = NULL;\n", native_driver);
}
