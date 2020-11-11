//This is executed by the Adam task at boot.
//See $LK,"Adam Start-up",A="FF:::/Kernel/KMain.HC,\"StartOS"$.

#help_index "Compiler/Directive"
public extern I8i Option(I64i num,I8i val);
Option(0,0); //(0,0)=EchoOff   (0,1)=EchoOn

#include "/Kernel/KernelA.HH"
#include "/Compiler/CompilerA.HH"
#include "/Kernel/KernelB.HH"
#include "/Kernel/KernelC.HH"
#include "/Compiler/CompilerB.HH"

Option(OPTf_WARN_PAREN,ON);
Option(OPTf_WARN_DUP_TYPES,ON);
HashTablePurge(adam_task->hash_table);

#include "/Adam/MakeAdam"

//Dbg("Type 'G;'");
DocTermNew;
//Raw(ON); -- this breaks inputs in KCfg
WinVert(2,10);

if (DrvIsWritable)
  DirMk("/Tmp"); //Good to have a Tmp

DirMk("/Home");			// needed why?

DirMk("/0000Boot");		// needed why?
#include "/Adam/Opt/Boot/MakeBoot"
#include "/Adam/Opt/Utils/MakeUtils"

Cd(__DIR__);;

#include "ShrineCfg"
#include "ShrineDistro"

// Make 128MB RAMdisk B: (Distro tree + ISO are built here)
CBlkDev* res;
res=BlkDevNextFreeSlot('B',BDT_RAM);
res->unit = 0;
res->max_blk = 0x40000-1;
BlkDevAdd(res,,TRUE,TRUE);

MakeStdDistro;
CopySingle("B:/Shrine.ISO.C", "C:/Shrine.ISO");
