#define LAMBDA_BITMAP 0x006336363C181B0E
#define LAMBDA "\xFB"
#define LAMBDA_CHARCODE 0xFB

#define AUTOCOMPLETE_MAX_RESULTS 15

// -------------------------------------
// History

class histent {
  histent*  next;
  U8        text[0];
};

histent* history;

Bool LoadHistory() {
  history = NULL;
  return TRUE;
}

U0 HistoryPush(U8* line) {
  if (!line[0])
    return;

  if (history && !StrCmp(history->text, line))
    return;

  I64 len = StrLen(line);
  histent* ent = MAlloc(sizeof(histent) + len + 1);
  StrCpy(ent->text, line);
  ent->next = history;
  history = ent;
}

// -------------------------------------
// Line input

U8* ReadLine(U8* prompt, I64 (*autocomplete)(U8* buffer) = NULL) {
  static U8 buf[256];
  I64 len = 0;
  histent* hist = history;

  buf[0] = 0;

show_prompt:

  DocBottom;
  "" prompt;
  "" buf;

  while (len < 255) {
    I64 scan;
    I64 ch = GetKey(&scan, FALSE, FALSE);

    if (ch == CH_BACKSPACE) {
      if (len > 0) {
        '' CH_BACKSPACE;
        --len;
      }
    }
    else if (ch == CH_ESC) {
      len = 0;
      buf[len] = 0;

      EdLineDel(DocPut);
      goto show_prompt;
    }
    else if (ch == CH_SHIFT_ESC) {
      return 0;
    }
    else if (ch == '\t' && autocomplete) {
      buf[len] = 0;

      // Completing path or last argument?
      U8* start = StrLastOcc(buf, " ");

      if (start)
        start++;
      else
        start = buf;

      // Find matching results
      I64 results = autocomplete(start);
      len = StrLen(buf);

      // If multiple results were printed,
      // we need to wait for the WinMgr (or whoever)
      // to catch up. UGH!
      if (results > 1)
        Sleep(200);

      EdLineDel(DocPut);
      goto show_prompt;
    }
    else if (ch == 0 && scan.u8[0] == SC_CURSOR_UP) {
      if (hist) {
        StrCpy(buf, hist->text);
        len = StrLen(buf);
        hist = hist->next;

        EdLineDel(DocPut);
        goto show_prompt;
      }
    }
    else if (ch) {
      '' ch;

      if (ch == '\n')
        break;

      buf[len++] = ch;
    }
  }
  buf[len] = 0;
  return buf;
}

// -------------------------------------
// Parse

I64 Tokenize(U8* str, U8** tokens) {
  I64 count = 0;
  Bool started = FALSE;

  while (*str) {
    if (*str == ' ') {
      if (started) {
        *str = 0;
        started = FALSE;
      }
    }
    else if (!started) {
      tokens[count] = str;
      count++;
      started = TRUE;
    }

    str++;
  }

  return count;
}

U0 TransformCommand(U8* command, U8* exec_buf) {
  Bool upperize = TRUE;
  I64 pos = 0;

  for (; *command; command++) {
    if (*command == '-')
      upperize = TRUE;
    else if (upperize) {
      exec_buf[pos++] = ToUpper(*command);
      upperize = FALSE;
    }
    else
      exec_buf[pos++] = *command;
  }

  exec_buf[pos] = 0;
}

// -------------------------------------
// Autocomplete

class CHashTableIter {
  CHashTable* ht;
  I64 i;
  CHash* curr;
  I64 recursive;
};

U0 HashTableIterBegin(CHashTableIter* it, CHashTable* ht, I64 recursive) {
  it->ht = ht;
  it->i = 0;
  it->curr = NULL;
  it->recursive = recursive;
}

CHash* HashTableIterNext(CHashTableIter* it) {
  // End of current bucket?
  while (!it->curr) {
    // End of hash table?
    while (it->i >= it->ht->mask) {
      // If recursive search is enabled,
      // jump to the next table in chain
      if (it->recursive) {
        if (!it->ht->next)
          return NULL;

        it->ht = it->ht->next;
        it->i = 0;
      }
      else
        return NULL;
    }

    it->curr = it->ht->body[it->i];
    it->i++;
  }

  CHash* ret = it->curr;
  it->curr = it->curr->next;
  return ret;
}

class CAutocompleteIter {
  U8* query;
  I64 length;
  CDirEntry* entries;
  CDirEntry* de;
  CHashTableIter hti;
};

class CAutocompleteResult {
  // Exactly one of these will be set
  CDirEntry* de;
  CHashFun* fun;
};

U0 AutocompleteIterRewind(CAutocompleteIter* it) {
  it->de = it->entries;
  HashTableIterBegin(&it->hti, Fs->hash_table, TRUE);
}

U0 AutocompleteIterBegin(CAutocompleteIter* it, U8* query) {
  it->query = query;
  it->length = StrLen(query);

  U8* mask = MStrPrint("%s*", query);
  try {
    it->entries = FilesFind(mask);
  }
  catch {
    it->entries = NULL;
  }
  Free(mask);

  AutocompleteIterRewind(it);
}

I64 AutocompleteIterNext(CAutocompleteIter* it, CAutocompleteResult* out) {
  // Go through all file matches first
  while (it->de) {
    if (it->de->name[0] != '.') {
      // Return the DE, iteration will resume at the next one
      out->de = it->de;
      out->fun = NULL;
      it->de = it->de->next;
      return TRUE;
    }

    it->de = it->de->next;
  }

  // Go through all hashtable matches
  CHash* next;
  while ((next = HashTableIterNext(&it->hti))) {
    // Function?
    if ((next->type & HTT_FUN) != 0
        && !StrNICmp(next->str, it->query, it->length)) {
      out->de = NULL;
      out->fun = next(CHashFun*);
      return TRUE;
    }
  }

  return FALSE;
}

U0 AutocompleteIterEnd(CAutocompleteIter* it) {
  DirTreeDel(it->entries);
}

U0 AutocompleteSetResult(U8* buffer, U8* str, I64 length) {
  // Completing path or last argument?
  U8* start = StrLastOcc(buffer, "/");

  if (start)
    start++;
  else
    start = buffer;

  MemCpy(start, str, length);
  start[length] = 0;
}

I64 StrCommonSubset(U8* a, U8* b) {
  I64 len = 0;
  while (*a && *b == *a) {
    a++;
    b++;
    len++;
  }
  return len;
}

// No matches -> return 0
// 1 match -> return 1, set *p_match to alloced
// multiple matches -> print matches, return count
I64 Autocomplete(U8* buffer) {
  // This is somewhat complicated, because we want
  // to avoid any unnecessary allocations.

  CAutocompleteIter it;
  CAutocompleteResult first, next;

  AutocompleteIterBegin(&it, buffer);

  if (!AutocompleteIterNext(&it, &first)) {
    // No results.
    return 0;
  }

  I64 count;
  U8* str;

  if (!AutocompleteIterNext(&it, &next)) {
    // Single result.

    if (first.de)
      str = first.de->name;
    else if (first.fun)
      str = first.fun->str;

    AutocompleteSetResult(buffer, str, StrLen(str));

    count = 1;
  }
  else {
    U8* common_base = NULL;
    I64 common_length = 0;

    AutocompleteIterRewind(&it);

    count = 0;
    "\n";

    while (count < AUTOCOMPLETE_MAX_RESULTS
        && AutocompleteIterNext(&it, &next)) {
      if (next.de) {
        str = next.de->name;
        "$FG,4$%s\n", str;
      }
      else if (next.fun) {
        str = next.fun->str;
        "$FG,3$%s\n", str;
      }

      if (!common_base) {
        common_base = str;
        common_length = StrLen(common_base);
      }
      else {
        I64 new_common = StrCommonSubset(common_base, str);
        if (common_length > new_common)
          common_length = new_common;
      }

      count++;
    }

    if (AutocompleteIterNext(&it, &next))
      "$FG,6$Too many results, display truncated\n$FG$";
    else if (common_length > StrLen(buffer))
      AutocompleteSetResult(buffer, common_base, common_length);
  }

  AutocompleteIterEnd(&it);
  return count;
}

// -------------------------------------
// Shell

Bool skip_intro = FALSE;

U8* DirCurShort() {
  U8* dir = DirCur();
  // FIXME!!
  if (!StrCmp(dir, "C:/Home")) {
    Free(dir);
    return StrNew("~");
  }
  else
    return dir;
}

CHashFun* FindFunction(U8* name) {
  CHash* result = HashFind(name, Fs->hash_table, HTT_FUN);

  if (result && (result->type & HTT_FUN) != 0)
    return result(CHashFun *);
  else
    return NULL;
}

Bool IsPath(U8* str) {
  for (; *str; str++) {
    if (*str == '/')
      return TRUE;
  }

  return FALSE;
}

U8* Prompt() {
  // TODO: Avoid malloc if we can rely on MAX_PATH
  static U8 buf[200];  
  U8* dir = DirCurShort();

  //StrPrint(buf, "$FG,5$" LAMBDA " $FG,8$%s $FG,0$", dir);
  StrPrint(buf, "$FG,8$%s $FG,5$" LAMBDA " $FG,0$", dir);
  Free(dir);
  return buf;
}

U0 PatchFont() {
  U64* font = sys_font_std;
  font[LAMBDA_CHARCODE] = LAMBDA_BITMAP;
}

// -------------------------------------
// Main

U0 Intro() {
  "\n"
  "$FG,1$- #include files by absolute or relative path\n"
  "  $FG,7$" LAMBDA "$FG,0$ ./Lsh $FG,7$=> #include \"Lsh\"\n"
  "\n"
  "$FG,1$- Call functions\n"
  "  $FG,7$" LAMBDA "$FG,0$ cd .. $FG,7$=> Cd(\"..\");\n"
  "  $FG,7$" LAMBDA "$FG,0$ dir $FG,7$=> Dir;\n"
  "  $FG,7$" LAMBDA "$FG,0$ ed Program.HC $FG,7$=> Ed(\"Program.HC\");\n"
  "  $FG,7$" LAMBDA "$FG,0$ file-mgr $FG,7$=> FileMgr;\n"
  "\n"
  "$FG,1$- Execute code directly\n"
  "  $FG,7$" LAMBDA "$FG,0$ 'DskChg('B');\n"
  "\n"
  "$FG,1$- $FG,0$Esc$FG,1$ deletes line\n"
  "$FG,1$- $FG,0$Tab$FG,1$ auto-completes paths\n"
  "$FG,1$- $FG,0$Shift-Esc$FG,1$ quits\n"
  "$FG,1$- $FG,0$Up Arrow$FG,1$ recalls previous commands\n"
  "\n";
}

U0 ParseAndExecute(U8* line) {
  if (line[0] == '#')
    return;

  if (line[0] == '\'') {
    ExePutS(line + 1);
    return;
  }

  U8* tokens[10];
  I64 count = Tokenize(line, tokens);

  if (count) {
    if (IsPath(tokens[0])) {
      "$FG$";
      ExePrint("#include \"%s\";", tokens[0]);
    }
    else {
      U8 exec_buf[200];

      TransformCommand(tokens[0], exec_buf);
      CHashFun* fun = FindFunction(exec_buf);

      if (!fun) {
        "%s: $FG,4$function not found$FG$\n", exec_buf;
        return;
      }

      if (count > 1) {
        CatPrint(exec_buf, "(");
        I64 have;
        for (have = 1; have < count; have++) {
          if (have > 1)
            CatPrint(exec_buf, ",");

          CatPrint(exec_buf, "\"%s\"", tokens[have]);
        }
        CatPrint(exec_buf, ")");
      }
      CatPrint(exec_buf, ";");
      "$FG,7$%s\n$FG$", exec_buf;
      ExePutS(exec_buf);
    }
  }
}

U0 Lsh() {
  PatchFont();
  LoadHistory();

  if (!skip_intro) {
    "$FG,8$Welcome to $FG,5$Lambda Shell$FG,8$!\n";
    "Type $FG,0$intro$FG,8$ for a quick introduction.\n\n";
  }

  while (1) {
    U8* p = Prompt();
    U8* line = ReadLine(p, &Autocomplete);

    if (!line || !StrCmp(line, "exit"))
      break;

    HistoryPush(line);

    try {
      ParseAndExecute(line);
    }
    catch {
      PutExcept();
    }
  }

  "$FG$\n";
}
