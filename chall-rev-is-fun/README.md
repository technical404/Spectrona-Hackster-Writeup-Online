# CTF Report — `chall.exe` (rev is fun)

**Category:** Reverse Engineering
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{rev_is_fun}`

---

## TL;DR

`chall.exe` is a modded twin of `chall0.exe` (same size, ~10 KB differ). The
troll continues — the "correct" answer to "What is 2 + 2 ?" is `49`. Uniquely,
this time the flag is stored as a **UTF-16LE wide string** in `.rdata` and is
**never printed** by any code path: it is a pure static-extraction target.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `chall.exe` (same folder as this report) |
| Size | `41,533` bytes (same as `chall0.exe`) |
| Type | PE32 console (MinGW i386) |
| MD5 | `e1d5a242b316a65f48e57152e1b2db46` |

---

## 2. What changed vs `chall0.exe`

* Question is now **"What is 2 + 2 ?"** and the expected answer is again a troll
  (`49`).
* Success message: `"Correct! But something feels... sus."`
* The flag is a **UTF-16LE** wide string at `0x405134`:

```
48 00 4B 00 53 00 54 00 52 00 7B 00 72 00 65 00 76 00 5F 00 69 00 73 00 5F 00 66 00 75 00 6E 00 7D 00
```

which decodes to `HKSTR{rev_is_fun}`.

---

## 3. Control flow (`main` @ `0x401460`)

```c
scanf("%49s", buf);
strcmp(buf, "49");     // answer key (troll)
puts(correct_or_wrong_message);
// copies the UTF-16 flag bytes from .rdata onto the stack (0x4014f0–0x40154b)
// ... but NEVER calls puts/printf on them
```

The flag is loaded into stack but not emitted — so there is no input that reveals
it at runtime. You must read it statically.

---

## 4. Extracting the flag

Wide-string search:

```bash
strings -a -e l chall.exe | grep -i HKSTR
# HKSTR{rev_is_fun}
```

Or read the raw bytes at `0x405134` and decode as UTF-16LE.

---

## 5. Flag

```
HKSTR{rev_is_fun}
```

---

## 6. Takeaways

* `strings -e l` (16-bit little-endian) catches **wide/UTF-16** strings that plain
  `strings` misses — always try both on Windows PE files.
* A secret that is *present but unused* still counts: dead stack copies don't
  protect data.

---

## Tools used

`file`, `md5sum`, `strings -e l`, disassembler.

*Write-up by **Priyank Rastogi**.*