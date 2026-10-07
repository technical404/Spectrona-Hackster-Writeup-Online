# CTF Report — `memdump` (Volatility: Credential Recovered from Memory)

**Category:** Digital Forensics / Memory Analysis
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{v0l4tilty_n3w6i3_4n6_ch4l}`

---

## TL;DR

`memdump.zip` unpacks to a **1 GB Windows memory image** (`memdump.mem`). A
malicious Python script (`shadow_agent.py`) was run with a secret credential on
its command line. The credential is split across memory: its **prefix** survives
in the process `argv` (`--job=...`), and its **suffix** is stored double-Base64
encoded in the script's string constants. Reassembling them yields the flag.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `memdump.zip` / `memdump.mem` (same folder as this report) |
| Size | `memdump.mem` = 1,073,676,288 bytes (~1 GB) |
| Type | Windows memory capture |
| Tooling | plain `strings`/hexdump was sufficient (Volatility optional) |

> A plain `strings` pass was enough here — no Volatility profile was required.

---

## 2. Recon

```bash
strings -n 6 memdump.mem | grep -aiE 'HKSTR|shadow_agent|--job|base64|credential'
```

Key findings:

```
python shadow_agent.py --job=HKSTR{v0l4tilty_n3w6i3 --mode=stealth
C:\Users\win\Desktop\shadow_agent.py
[!] Secret Credential Base:64 You are near Flag | _4n6_ch4l}
WHpSdU5sOWphRFJzZlE9PQ==
"CTF{v0latility_n3wbi3"
```

* The `--job=` argument is the **runtime credential**, but it is
  **NUL-truncated** in memory — only the prefix `HKSTR{v0l4tilty_n3w6i3` survived
  contiguously.
* The script embeds a hint string `[!] Secret Credential Base:64 ... | _4n6_ch4l}`
  and a blob `WHpSdU5sOWphRFJzZlE9PQ==`.
* A literal `"CTF{v0latility_n3wbi3"` is a **decoy** (plain spelling, wrong
  `CTF{` prefix, and `n3wbi3` vs the real `n3w6i3`).

---

## 3. Decoding the suffix (double Base64)

```bash
echo 'WHpSdU5sOWphRFJzZlE9PQ==' | base64 -d | base64 -d
# _4n6_ch4l}
```

* `WHpSdU5sOWphRFJzZlE9PQ==` -> `XzRuNl9jaDRsfQ==` -> `_4n6_ch4l}`

---

## 4. Assembling the flag

```
prefix (from --job=)   : HKSTR{v0l4tilty_n3w6i3
suffix (double-b64)    : _4n6_ch4l}
--------------------------------------------------
HKSTR{v0l4tilty_n3w6i3_4n6_ch4l}
```

The real credential uses the `HKSTR{...}` prefix with leetspeak (`4`=a, `6`=b),
matching the encoded suffix style (`_4n6_ch4l` = "forensics chall").

---

## 5. Flag

```
HKSTR{v0l4tilty_n3w6i3_4n6_ch4l}
```

---

## 6. Takeaways

* Command lines leak secrets: process `argv` in a memory image frequently holds
  credentials, API keys, and flags.
* A **NUL-truncated** `argv` string often has its remainder elsewhere in memory —
  search globally for the continuation, don't stop at the first fragment.
* Base64 is used in layers: attempt **double** decode before concluding a blob is
  noise.
* Watch for **decoys** (`CTF{...}` / different spelling) planted to misdirect.

---

## Tools used

`strings`, `grep`, `hexdump`, `base64` (Volatility available but not required).

*Write-up by **Priyank Rastogi**.*