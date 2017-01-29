#include "::/Doc/Comm"

CComm* comm;
U8 in_buf[256];

U8* ReadStr() {
  I64 len = 0;
  while (1) {
    if (FifoU8Rem(comm->RX_fifo, in_buf + len)) {
      if (in_buf[len] == '\n')
        break;
      len++;
    }
    else Yield;
  }
  in_buf[len] = 0;
  "%s\n", in_buf;
  return in_buf;
}

U0 ReadBlk(U8* buf, I64 count) {
  while (count) {
    if (FifoU8Rem(comm->RX_fifo, buf)) {
      buf++;
      count--;
    }
    else Yield;
  }
}

U0 Tmp()
{
  OnceExe;
  DocBottom;
  comm = CommInit8n1(1, 115200);

  while (1) {
    U8* command = ReadStr();
    I64 size;

    if (command[0] == 'L') {
      U8* file = FileRead(command + 1, &size);

      CommPrint(1, "S%d\n", size);
      CommPutBlk(1, file, size);
      Free(file);
    }
    else if (command[0] == 'P') {
      U8 filename[255];
      StrCpy(filename, command + 1);
      U8* next = ReadStr();
      StrScan(next, "S%d", &size);

      U8* file_buf = MAlloc(size);
      ReadBlk(file_buf, size);
      FileWrite(filename, file_buf, size);
      Free(file_buf);
    }
    else if (command[0] == '\'') {
      ExePutS(command + 1);
    }
    else if (command[0] == '?') {
      CommPutS(1, "!\n");
    }
  }
}

Tmp;
