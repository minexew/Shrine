// vim: set ft=cpp:

#include "::/Adam/Net/SnailLib"
#include "::/Adam/Net/Http"
#include "::/Adam/Net/Url"

#define PKG_EURL        (-20001)
#define PKG_EMOUNT      (-20002)
#define PKG_EMANIFEST   (-20003)
#define PKG_EVERSION    (-20004)
#define PKG_EOSVERSION  (-20005)
#define PKG_EUNSUITABLE (-20006)

#define PKG_VERSION     10

static U8* LOCAL_REPO_URL = "::/Misc/Packages";
static U8* PKG_BASE_URL = "http://shrineupd.ddns.net:8000/packages";

class CPkgInfo {
  U8*   package_name;
  I32   pkgmin;
  I32   release;
  I32   osmin;
  I32   osmax;
  I64   size;
  U8*   version;
  U8*   installdir;
  U8*   iso_c;
};

U0 PkgInfoInit(CPkgInfo* pinf) {
  pinf->package_name = 0;

  pinf->pkgmin = 0x7fffffff;
  pinf->release = 0;
  pinf->osmin = 0;
  pinf->osmax = 0x7fffffff;
  pinf->size = 0;

  pinf->version = 0;
  pinf->installdir = 0;
  pinf->iso_c = 0;
}

U0 PkgInfoFree(CPkgInfo* pinf) {
  Free(pinf->package_name);
  Free(pinf->version);
  Free(pinf->installdir);
  Free(pinf->iso_c);
  PkgInfoInit(pinf);
}

I64 PkgGetPkgInfo(CPkgInfo* pinf, U8* package_name) {
  pinf->package_name = StrNew(package_name);

  U8* url = MStrPrint("%s/%s", PKG_BASE_URL, package_name);

  U8* manifest = 0;
  I64 size = 0;
  I64 error = UrlGet(url, &manifest, &size);

  if (error == 0) {
    U8* key = manifest;

    while (*key) {
      //"?%s", key;
      U8* value = StrFirstOcc(key, "\t");
      if (!value) { error = PKG_EMANIFEST; break; }
      *value = 0;
      value++;

      U8* end = StrFirstOcc(value, "\n");
      if (end) {
        *end = 0;
        end++;
      }
      else
        end = value + StrLen(value);

      //"%s=%s;\n", key, value;

      if (0) {}
      else if (!StrCmp(key, "pkgmin")) { pinf->pkgmin = Str2I64(value); }
      else if (!StrCmp(key, "release")) { pinf->release = Str2I64(value); }
      else if (!StrCmp(key, "osmin")) { pinf->osmin = Str2I64(value); }
      else if (!StrCmp(key, "osmax")) { pinf->osmax = Str2I64(value); }
      else if (!StrCmp(key, "size")) { pinf->size = Str2I64(value); }
      else if (!StrCmp(key, "version")) { pinf->version = StrNew(value); }
      else if (!StrCmp(key, "installdir")) { pinf->installdir = StrNew(value); }
      else if (!StrCmp(key, "iso.c")) { pinf->iso_c = StrNew(value); }
      else { /* unrecognized keys are simply ignored */ }

      key = end;
    }
  }

  Free(url);
  return error;
}

U8* PkgAllocISOCUrl(CPkgInfo* pinf) {
  if (!pinf->iso_c)
    return 0;

  if (StrFind("//", pinf->iso_c))
    return StrNew(pinf->iso_c);
  else
    return MStrPrint("%s/%s", PKG_BASE_URL, pinf->iso_c);
}

I64 PkgInstallISOC(CPkgInfo* pinf, U8* iso_c) {
  I64 error = 0;
  "Installing %s\n", pinf->package_name;

  I64 letter = MountFile(iso_c);
  if (letter) {
    U8 src_path[8];
    StrPrint(src_path, "%c:/", letter);
    CopyTree(src_path, pinf->installdir);
  }
  else
    error = PKG_EMOUNT;

  Unmount(letter);
  return error;
}

I64 PkgDownloadAndInstall(CPkgInfo* pinf) {
  // Validate Pkg & OS version

  if (pinf->pkgmin > PKG_VERSION) {
    "$FG,6$This package requires a more recent version of $FG,5$Pkg\n";
    "$FG$Please update.\n";
    return PKG_EVERSION;
  }

  I64 osver = ToI64(sys_os_version * 100);

  if (osver < pinf->osmin) {
    "$FG,6$This package requires a more recent system version.\n";
    "$FG$Please update. (need %d, have %d)\n", pinf->osmin, osver;
    return PKG_EOSVERSION;
  }

  if (osver > pinf->osmax) {
    "$FG,6$This package is not compatible with your system version.\n";
    "$FG$Last supported version is %d, you have %d.\n", pinf->osmax, osver;
    return PKG_EOSVERSION;
  }

  U8* iso_c_url = PkgAllocISOCUrl(pinf);

  if (iso_c_url) {
    U8* iso_data = 0;
    I64 iso_size = 0;
    "Downloading %s...\n", pinf->package_name;

    I64 error = UrlGet(iso_c_url, &iso_data, &iso_size);

    if (error == 0) {
      U8* tmppath = "::/Tmp/Package.ISO.C";
      FileWrite(tmppath, iso_data, iso_size);
      error = PkgInstallISOC(pinf, tmppath);
    }

    Free(iso_data);
    Free(iso_c_url);
  }
  else {
    "$FG,6$No suitable download address. Package broken?\n";
    error = PKG_EUNSUITABLE;
  }

  return error;
}

// Expected max length: 5 ("1023k")
static U8* FormatSize(I64 size) {
  static U8 buf[16];
  if (size > 0x40000000)
    StrPrint(buf, "%dG", (size + 0x3fffffff) / 0x40000000);
  else if (size > 0x100000)
    StrPrint(buf, "%dM", (size + 0xfffff) / 0x100000);
  else if (size > 0x400)
    StrPrint(buf, "%dk", (size + 0x3ff) / 0x400);
  else
    StrPrint(buf, "%d", size);
  return buf;
}

I64 PkgInstall(U8* package_name) {
  SnailInit();
  MkDir(LOCAL_REPO_URL);

  CPkgInfo pinf;

  PkgInfoInit(&pinf);
  I64 error = PkgGetPkgInfo(&pinf, package_name);

  if (error == 0) {
    "$FG,8$  Package              Ver   \n"
    "$FG,8$  Dir                  Size  \n"
    "$FG,8$============================\n"
    "$FG,7$Install:\n";
    "$FG,2$+ %-20s %-6s\n", package_name, pinf.version;
    "$FG,2$  %-20s %-6s\n", pinf.installdir, FormatSize(pinf.size);
    "\n"
    "$FG$Is this ok? (y/n) ";
    I64 ok = GetKey(NULL, TRUE);
    "\n";

    // TODO: verify all packages before we start downloading

    if (ok == 'y') {
      error = PkgDownloadAndInstall(&pinf);

      if (error == 0) {
        "$FG,2$Installed 1 package(s)\n";
      }
      else {
        "$FG,4$PkgDownloadAndInstall error: %d\n$FG$", error;
      }
    }
  }
  else {
    "$FG,4$PkgGetPkgInfo error: %d\n$FG$", error;
  }

  PkgInfoFree(&pinf);

  return error;
}
