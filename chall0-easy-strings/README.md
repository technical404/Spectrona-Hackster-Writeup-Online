# CTF Report — `chall0.exe` (Easy Strings)

**Category:** Reverse Engineering
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{easy_strings}`

---

## Solution

`chall0.exe` is a small MinGW-compiled PE32 console quiz ("What is 1 + 1 ?").
The flag sits in plaintext in `.rdata` and is printed only when the user's
answer matches a hard-coded value. A quick `strings`/`.rdata` dump reveals it
immediately — hence "easy strings".

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `chall0.exe` (same folder as this report) |
| Size | `41,533` bytes |
| Type | PE32 console executable (MinGW / GCC 6.3.0, i386) |
| MD5 | `3d72be3b0a4ad20259d9eedfdeb7534a` |
| SHA-256 | `d0a51efad4ff60e3408edf534187660cdcb562facd81b4ed6adbb8ea45a4f9d5` |

```bash
file chall0.exe
md5sum chall0.exe
```

---

## 2. Static analysis

### 2.1 Strings in `.rdata`

```bash
strings -a chall0.exe | grep -i HKSTR
# HKSTR{easy_strings}
```

A `.rdata` dump shows the relevant constants:

```
0x004050a8  "Question: What is 1 + 1 ?"
0x004050c2  "Your answer: "
0x004050d0  "%49s"
0x004050d8  "HKSTR{easy_strings}"     <-- the flag
0x004050ec  "Wrong answer! Better luck next time."
```

### 2.2 Control flow (`main` @ `0x401460`)

Decompiled logic:

```c
puts("Question: What is 1 + 1 ?");
printf("Your answer: ");
scanf("%49s", buf);
if (strcmp(buf, "17") == 0)          // <- the "twist": answer is 17, not 2
    puts((char*)0x4050d8);           // prints "HKSTR{easy_strings}"
else
    puts("Wrong answer! Better luck next time.");
```

So the **real correct input is `17`** — the little troll in the quiz — but the
flag itself is recoverable statically without running the binary at all.

---

## 3. Solving

```bash
strings -a chall0.exe | grep HKSTR
```

If you prefer to run it (Wine):

```bash
printf '17\n' | wine chall0.exe
# ...prints HKSTR{easy_strings}
```

---

## 4. Flag

```
HKSTR{easy_strings}
```

---

## 5. Takeaways

* Always start RE with `strings`/`grep` for flag patterns before disassembling.
* `.rdata` (read-only data) commonly holds plaintext secrets; even a UTF-16 or
  XOR-obfuscated variant would fall to a quick dump.

---

## Tools used

`file`, `md5sum`, `strings`, `objdump`/disassembler.

*Write-up by **Priyank Rastogi**.*