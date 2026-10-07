# CTF Report — `memdump` / `HKSTR{5976}` (Malicious Process ID)

**Category:** Digital Forensics / Memory Analysis (Windows)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{5976}`

---

## TL;DR

A second question on the Windows memory image (`memdump.mem`): identify the **PID**
of the malicious process. The image contains a process launched from
`...\Desktop\HKSTR{replace with process_id}.exe`, and the challenge's flag
template explicitly asks for the **`process_id`**. That process runs as **PID
5976**.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `memdump.mem` (same folder as this report) |
| Size | ~1 GB |
| Type | Windows memory capture |
| Tooling | Volatility 3 (`windows.pslist`, `windows.pstree`) |

---

## 2. Findings

A `strings` sweep of the image surfaces a literal flag template:

```
HKSTR{replace with process_id}
```

i.e. the challenge wants the **process id** of the malicious executable, whose
on-disk name is `HKSTR{replace with process_id}.exe` (a placeholder the author
never renamed).

Process listing (Volatility, `windows.pslist`), filtered:

```
PID    PPID   ImageFileName                     CreateTime
5088   2720   explorer.exe                      2026-01-21 08:20:54 UTC
5976   5088   HKSTR{replace ...}.exe            2026-01-21 08:20:55 UTC   <-- malicious
6336   5976   conhost.exe                       2026-01-21 08:20:55 UTC
```

* The suspicious process runs from
  `C:\Users\userzero\Desktop\HKSTR{replace with process_id}.exe`.
* **PID `5976`**, parent **`explorer.exe` (5088)**, launched at `08:20:55`, and it
  spawns `conhost.exe` (6336) seconds later — a classic "user double-clicked a
  script/exe" pattern.

```bash
vol -f memdump.mem windows.pstree | grep -iE 'explorer|HKSTR|5976|5088|conhost'
vol -f memdump.mem windows.cmdline --pid 5976
```

---

## 3. Flag

```
HKSTR{5976}
```

---

## 4. Takeaways

* The flag template itself (`replace with process_id`) is the hint — the author
  shipped a placeholder name that tells you exactly what value is wanted.
* Process **tree** context (parent = `explorer.exe`, child = `conhost.exe`) plus a
  suspicious filename/creation time is enough to uniquely identify the malicious
  PID.

---

## Tools used

`volatility3` (`windows.pslist`, `windows.pstree`, `windows.cmdline`), `strings`.

*Write-up by **Priyank Rastogi**.*