extern Bool HostFsFileFind(CDrv *dv,I64 cur_dir_clus,U8 *name,
        CDirEntry *_res,I64 fuf_flags=0);

extern U8 *HostFsFileRead(CDrv *dv,U8 *cur_dir,U8 *filename,I64 *_size,I64 *_attr);

extern Bool HostFsCd(U8 *name,I64 cur_dir_clus);
