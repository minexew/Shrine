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

DirMk("/Home");
Copy("/MakeHome.HC.Z", "/Home/MakeHome.HC.Z");

#include "/Adam/Opt/Boot/MakeBoot"
#include "/Misc/DoDistro"
