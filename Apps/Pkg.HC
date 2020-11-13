#include "::/Adam/Net/Url"

#define PKG_EURL        (-20001)
#define PKG_EMOUNT      (-20002)
#define PKG_EMANIFEST   (-20003)
#define PKG_EVERSION    (-20004)
#define PKG_EOSVERSION  (-20005)
#define PKG_EUNSUITABLE (-20006)

#define PKG_VERSION     11

static U8* PKG_BASE_URL =     "http://update.shrine.systems/packages";
static U8* PKG_LOCAL_REPO =   "::/Misc/Packages";
static U8* PKG_TMP_DIR =      "::/Tmp/PkgTmp";

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
  U8*   post_install_doc;
};

// TODO: Is there a built-in for this?
static U8* StripDir(U8* file_path) {
  U8* slash = StrLastOcc(file_path, "/");

  if (slash)
    return slash + 1;
  else
    return file_path;
}

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
  pinf->post_install_doc = 0;
}

U0 PkgInfoFree(CPkgInfo* pinf) {
  Free(pinf->package_name);
  Free(pinf->version);
  Free(pinf->installdir);
  Free(pinf->iso_c);
  Free(pinf->post_install_doc);
  PkgInfoInit(pinf);
}

// Returns 0 or error code
I64 PkgParseManifest(CPkgInfo* pinf, U8* manifest) {
  U8* key = manifest;

  while (*key) {
    //"?%s", key;
    U8* end = StrFirstOcc(key, "\n");
    if (end) {
      *end = 0;
      end++;
    }
    else
      end = key + StrLen(key);

    U8* value = StrFirstOcc(key, "\t");

    if (!value)
      return PKG_EMANIFEST;

    *value = 0;
    value++;

    //"%s=%s;\n", key, value;

    if (0) {}
    else if (!StrCmp(key, "name")) { Free(pinf->package_name); pinf->package_name = StrNew(value); }
    else if (!StrCmp(key, "pkgmin")) { pinf->pkgmin = Str2I64(value); }
    else if (!StrCmp(key, "release")) { pinf->release = Str2I64(value); }
    else if (!StrCmp(key, "osmin")) { pinf->osmin = Str2I64(value); }
    else if (!StrCmp(key, "osmax")) { pinf->osmax = Str2I64(value); }
    else if (!StrCmp(key, "size")) { pinf->size = Str2I64(value); }
    else if (!StrCmp(key, "version")) { Free(pinf->version); pinf->version = StrNew(value); }
    else if (!StrCmp(key, "installdir")) { Free(pinf->installdir); pinf->installdir = StrNew(value); }
    else if (!StrCmp(key, "iso.c")) { Free(pinf->iso_c); pinf->iso_c = StrNew(value); }
    else if (!StrCmp(key, "post-install-doc")) { Free(pinf->post_install_doc); pinf->post_install_doc = StrNew(value); }
    else { /* unrecognized keys are simply ignored */ }

    key = end;
  }

  return 0;
}

I64 PkgWriteManifest(CPkgInfo* pinf, U8* path) {
  // TODO: implement

  no_warn pinf;
  FileWrite(path, "", 0);
  return 0;
}

// Downloads a package info from the repository.
// Returns 0 or error code
I64 PkgFetchManifest(CPkgInfo* pinf, U8* package_name) {
  // Old packages didn't have to specify a name, so we'll keep this for now
  pinf->package_name = StrNew(package_name);

  U8* url = MStrPrint("%s/%s", PKG_BASE_URL, package_name);

  U8* manifest = 0;
  I64 size = 0;
  I64 error = UrlGet(url, &manifest, &size);

  if (error == 0)
    error = PkgParseManifest(pinf, manifest);

  Free(manifest);
  Free(url);
  return error;
}

// Get the URL of the package's ISO.C download.
// Returns NULL if N/A, otherwise must be Free()d.
U8* PkgAllocISOCUrl(CPkgInfo* pinf) {
  if (!pinf->iso_c)
    return NULL;

  // A bit hacky, but will probably always work
  if (StrFind("//", pinf->iso_c))
    return StrNew(pinf->iso_c);
  else
    return MStrPrint("%s/%s", PKG_BASE_URL, pinf->iso_c);
}

// Check if the package metadata makes it viable for installation.
// You still need to do PkgCheckCompatibility, dependency resolution,
// and check for a suitable installable format.
Bool PkgIsInstallable(CPkgInfo* pinf) {
  return pinf->package_name != NULL && pinf->version != NULL && pinf->installdir != NULL;
}

// Check if the package is compatible with this OS & Pkg version
I64 PkgCheckCompatibility(CPkgInfo* pinf) {
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

  return 0;
}

I64 PkgRegister(CPkgInfo* pinf) {
  // TODO: this is very preliminary

  if (pinf->package_name == NULL)
    return PKG_EUNSUITABLE;

  U8* path = MStrPrint("%s/%s", PKG_LOCAL_REPO, pinf->package_name);

  PkgWriteManifest(pinf, path);

  return 0;
}

// Install a package, using the provided ISO.C file.
// This will also register the package as installed.
I64 PkgInstallISOC(CPkgInfo* pinf, U8* iso_c) {
  if (pinf->package_name == NULL || pinf->installdir == NULL)
    return PKG_EUNSUITABLE;

  I64 error = 0;
  "Installing %s\n$FG,7$", pinf->package_name;

  I64 letter = MountFile(iso_c);
  if (letter) {
    U8 src_path[8];
    StrPrint(src_path, "%c:/", letter);

    // StrLen check is a temporary hack to not complain about MkDir("::/");
    if (StrLen(pinf->installdir) > 3)
      DirMk(pinf->installdir);

    CopyTree(src_path, pinf->installdir);

    // Register package as installed
    error = PkgRegister(pinf);

    // Display post-install doc
    if (pinf->post_install_doc) {
      Ed(pinf->post_install_doc);
    }
  }
  else
    error = PKG_EMOUNT;

  Unmount(letter);
  "$FG$";
  return error;
}

// Verify, download & install a single package
// All dependencies must have been installed at this point.
I64 PkgDownloadAndInstall(CPkgInfo* pinf) {
  I64 error = PkgCheckCompatibility(pinf);
  if (error) { return error; }

  U8* iso_c_url = PkgAllocISOCUrl(pinf);

  if (iso_c_url) {
    U8* iso_data = 0;
    I64 iso_size = 0;
    "Downloading %s...\n", pinf->package_name;

    error = UrlGetWithProgress(iso_c_url, &iso_data, &iso_size);

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

// Install a package using a local manifest file
public I64 PkgInstallFromFile(U8* manifest_path) {
  DirMk(PKG_LOCAL_REPO);

  CPkgInfo pinf;
  PkgInfoInit(&pinf);

  // Parse manifest
  I64 manifest_size;
  U8* manifest_file = FileRead(manifest_path, &manifest_size);

  // This relies on FileRead returning a 0-terminated buffer.
  // As of v502, this happens for all file systems
  I64 error = PkgParseManifest(&pinf, manifest_file);

  if (error == 0) {
    error = PkgCheckCompatibility(&pinf);

    if (!error) {
      if (pinf.iso_c) {
        PkgInstallISOC(&pinf, pinf.iso_c);
      }
      else {
        "$FG,6$No suitable installable file. Package broken?\n";
        error = PKG_EUNSUITABLE;
      }
    }
    else {
      "$FG,4$PkgCheckCompatibility error: %d\n$FG$", error;
    }
  }
  else {
    "$FG,4$PkgParseManifest error: %d\n$FG$", error;
  }

  PkgInfoFree(&pinf);
  return error;
}

// Install a package from the repository
public I64 PkgInstall(U8* package_name) {
  SocketInit();
  DirMk(PKG_LOCAL_REPO);

  CPkgInfo pinf;

  PkgInfoInit(&pinf);
  I64 error = PkgFetchManifest(&pinf, package_name);

  if (error == 0) {
    if (PkgIsInstallable(&pinf)) {
      "$FG,8$  Package              Ver   \n"
      "$FG,8$  Dir                  Size  \n"
      "$FG,8$============================\n"
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
      "$FG,4$PkgInstall: %s is not installable\n$FG$", package_name;
      error = PKG_EUNSUITABLE;
    }
  }
  else {
    "$FG,4$PkgFetchManifest error: %d\n$FG$", error;
  }

  PkgInfoFree(&pinf);

  return error;
}

// List packages available in the repository
public I64 PkgList() {
  SocketInit();

  U8* url = MStrPrint("%s/packages.list", PKG_BASE_URL);

  U8* list = 0;
  I64 size = 0;
  I64 error = UrlGet(url, &list, &size);

  if (error == 0) {
    "$FG,2$%s\n", list;

    /*U8* entry = list;

    while (*entry) {
      U8* end = StrFirstOcc(entry, "\n");
      if (end) {
        *end = 0;
        end++;
      }
      else
        end = value + StrLen(value);

      "$FG,2$%s\n", entry;

      entry = end;
    }*/
  }
  else {
    "$FG,4$UrlGet error: %d\n$FG$", error;
  }

  Free(list);
  Free(url);
  return error;
}

// Build a package from directory contents
public I64 PkgMakeFromDir(U8* manifest_path, U8* src_dir) {
  CPkgInfo pinf;
  PkgInfoInit(&pinf);

  // Parse manifest
  I64 manifest_size;
  U8* manifest_file = FileRead(manifest_path, &manifest_size);

  // This relies on FileRead returning a 0-terminated buffer.
  // As of v502, this happens for all file systems
  I64 error = PkgParseManifest(&pinf, manifest_file);

  if (error == 0) {
    // Build RedSea ISO
    if (pinf.iso_c) {
      U8* iso_path = pinf.iso_c;

      // RedSeaISO doesn't return a proper error code
      RedSeaISO(iso_path, src_dir);

      // TODO: update & save manifest
      /*CDirEntry* de;
      if (FileFind(iso_path, &de)) {
        pinf.size = de.size;

        // Save updated manifest
        PkgWriteManifest(&pinf, manifest_path);

        Free(de->full_name);
      }
      else {
        "$FG,6$Something went wrong, can't stat %s.\n", iso_path;
        error = PKG_EMOUNT;
      }*/
    }
    else {
      "$FG,6$No output file defined.\n";
      error = PKG_EUNSUITABLE;
    }
  }
  else {
    "$FG,4$PkgParseManifest error: %d\n$FG$", error;
  }

  PkgInfoFree(&pinf);
  return error;
}

// Build a package using a single file
I64 PkgMakeFromFile(U8* manifest_path, U8* file_path) {
  DelTree(PKG_TMP_DIR);
  DirMk(PKG_TMP_DIR);

  U8* tmppath = MStrPrint("%s/%s", PKG_TMP_DIR, StripDir(file_path));
  Copy(file_path, tmppath);

  I64 error = PkgMakeFromDir(manifest_path, PKG_TMP_DIR);

  Free(tmppath);
  return error;
}
