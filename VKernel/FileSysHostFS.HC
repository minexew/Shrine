Bool HostFsFileFind(CDrv *dv,I64 cur_dir_clus,U8 *name,
        CDirEntry *_res,I64 fuf_flags=0)
{//$LK,"FUF_JUST_DIRS",A="MN:FUF_JUST_DIRS"$, $LK,"FUF_JUST_FILES",A="MN:FUF_JUST_FILES"$
  CDirEntry *abs_path,*buf2,*ptr;
  U8 dname[CDIR_FILENAME_LEN];
  I64 ch;
  Bool res=FALSE,unlock;
  if (fuf_flags&~FUG_FILE_FIND)
    throw('FUF');
  MemSet(_res,0,sizeof(CDirEntry));
  DrvChk(dv);
  if (dv->fs_type!=FSt_HOSTFS)
    PrintErr("Not HostFS Drv\n");
  else if (!CFileNameTo(dname,name))
    PrintErr("Invalid FileName: \"%s\".\n",name);
  else {
    //unlock=DrvLock(dv);

    CHostFsStat stat;

    // Build absolute path, if needed
    if (cur_dir_clus) {
      if (VSysCall(VSYSCALL_STATCLUS, cur_dir_clus, &stat, 0) == 0) {
        abs_path = MAlloc(StrLen(stat.abs_path)+1+StrLen(name)+1);
        StrCpy(abs_path, stat.abs_path);
        CatPrint(abs_path, "/");
        CatPrint(abs_path, name);
      }
      else {
        PrintErr("Invalid directory");
        abs_path = 0;
      }
    }
    else {
      abs_path = MAlloc(1+StrLen(name)+1);
      StrCpy(abs_path, "/");
      CatPrint(abs_path, name);
    }

    if (abs_path && VSysCall(VSYSCALL_STAT, abs_path, &stat, 0) == 0) {
      if (!(fuf_flags&FUF_JUST_DIRS && !(stat.attr & RS_ATTR_DIR)) &&
          !(fuf_flags&FUF_JUST_FILES && stat.attr & RS_ATTR_DIR)) {
        _res->attr=stat.attr;
        StrCpy(_res->name, name);   // FIXME: bounds etc
        _res->clus=stat.clus;
        _res->size=stat.size;
        _res->datetime.date = 0;    // TODO
        _res->datetime.time = 0;    // TODO
        res++;
      }
    }

    Free(abs_path);

    //if (unlock)
    //  DrvUnlock(dv);
  }
  return res;
}

U8 *HostFsFileRead(CDrv *dv,U8 *cur_dir,U8 *filename,I64 *_size,I64 *_attr)
{
  U8 *buf=NULL, *path=NULL;
  CDirEntry de;
  I64 c,blk_cnt,cur_dir_clus;
  DrvChk(dv);
  *_size=0;
  *_attr=0;
  if (dv->fs_type!=FSt_HOSTFS)
    PrintErr("Not HostFS Drv\n");
  else {
    path = MAlloc(StrLen(cur_dir) + 1 + StrLen(filename) + 1);
    path[0] = 0;
    StrCpy(path, cur_dir);
    CatPrint(path,"/");
    CatPrint(path,filename);
    // DrvLock(dv);

    CHostFsStat stat;

    if (VSysCall(VSYSCALL_STAT, path, &stat, 0) == 0) {
      buf = MAlloc(stat.size+1);
      *_size = VSysCall(VSYSCALL_FREAD, path, buf, stat.size);
      *_attr = stat.attr;
      buf[*_size] = 0;
    }

    // DrvUnlock(dv);
    Free(path);
  }
  return buf;
}

Bool HostFsCd(U8 *name,I64 cur_dir_clus)
{
  CDirEntry de;
  if (Fs->cur_dv->fs_type!=FSt_HOSTFS)
    PrintErr("Not HostFS Drv\n");
  else if (HostFsFileFind(Fs->cur_dv,cur_dir_clus,name,&de,FUF_JUST_DIRS))
    return TRUE;
  else
    PrintErr("File not found: \"%s\".\n",name);
  return FALSE;
}
