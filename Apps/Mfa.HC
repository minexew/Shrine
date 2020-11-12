#include "::/Doc/Comm"

#define MFA_COM 1

static CComm* comm;
static U8 in_buf[256];

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

U0 Mfa() {
  U8 command;

  comm = CommInit8n1(MFA_COM, 9600);
  while (FifoU8Rem(comm->RX_fifo, &command)) {}

  "$FG,5$minimalist file access\n"
  "\n"
  "$FG,8$- configure your VM's COM1 as follows:\n"
  "$FG,0$  TCP, server, port 7770\n"
  "$FG,8$- use $FG,5$mfa.py$FG,8$ to send commands & files\n"
  "\n"
  "awaiting commands. press Esc to quit\n";

  while (1) {
  next:
    I64 key;

    if (ScanKey(&key) && (key == CH_ESC || key == CH_SHIFT_ESC || key == 'q'))
      break;

    if (!FifoU8Rem(comm->RX_fifo, &command)) {
      Sleep(50);
      goto next;
    }

    '' command;
    U8* line = ReadStr();
    I64 size;

    if (command == 'L') {
      U8* file = FileRead(line, &size);

      CommPrint(MFA_COM, "S%d\n", size);
      CommPutBlk(MFA_COM, file, size);
      Free(file);

      "Sent %d\n", size;
    }
    else if (command == 'P') {
      U8 filename[255];
      StrCpy(filename, line);
      U8* next = ReadStr();
      StrScan(next, "S%d", &size);

      U8* file_buf = MAlloc(size);
      ReadBlk(file_buf, size);
      FileWrite(filename, file_buf, size);
      Free(file_buf);

      "Wrote %d\n", size;
    }
    else if (command == '\'') {
      ExePutS(line);
    }
    else if (command == '?') {
      CommPutS(MFA_COM, "!\n");
    }
  }

  "$FG$";
}

Mfa;
