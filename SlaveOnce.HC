#include "::/Doc/Comm"

U8 in_buf[255];
U8 out_buf[255];

U8* ReadStr() {
  I64 len = 0;
  while (1) {
    if (FifoU8Rem(comm_fifos[1], in_buf + len)) {
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
    if (FifoU8Rem(comm_fifos[1], buf)) {
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
  CommInit8n1(1, 9600);
  while (1) {
  U8* command = ReadStr();
  I64 size;

  if (command[0] == 'L') {
    U8* file = FileRead(command + 1, &size);

    StrPrint(out_buf, "S%d\n", size);
    CommBusyPutS(1, out_buf);
    CommBusyWriteBlk(1, file, size);
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
    CommBusyPutS(1, "!\n");
  }
  }
}

Tmp;
