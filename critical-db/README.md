# CTF Report — `Critical_db` (MIRA HQ — MD5 + RC4)

**Category:** Reverse Engineering / Crypto (stripped ELF64)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{MIRA_HQ-CENTRAL_DB_RECOVERED}`

---

## TL;DR

`Critical_db` is a stripped ELF64 PIE ("MIRA HQ – CENTRAL DB", Among Us themed).
It asks for an "Emergency Bypass Key". The binary MD5-hashes your input and
compares it to a hard-coded digest; once you supply the right key it **RC4-decrypts**
an embedded blob and prints the flag. The key is crackable with `hashcat` +
`rockyou` + the `d3ad0ne` rule.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `Critical_db` (same folder as this report) |
| Type | ELF 64-bit LSB PIE, stripped |
| MD5 | `024342342991bcb41cc2042a1f181a08` |
| Theme | "MIRA HQ – CENTRAL DB" |

---

## 2. Static analysis

### 2.1 The auth check (at `0x12e0`)

The binary hex-encodes the user's input (`sprintf("%02x", ...)`) and `strcmp`s the
32-char result against a string stored at `0x2300` that is **XOR-obfuscated with
`0x42`**:

```
obfuscated:  ${wzt $u'$r{{up&u&#" wq$p!'sp$$s
XOR 0x42 ->  f9586bf7ef09972d7daeb53f2ce12ff1
```

So the required key is a 16-character string whose **MD5 = `f9586bf7ef09972d7daeb53f2ce12ff1`**.
(MD5 constants at `0x2440` confirm a hand-rolled MD5 implementation.)

### 2.2 The success path (at `0x18c0`)

On a matching key the binary runs **RC4** (parameters derived from the ASCII sum
of the input) over an obfuscated blob at `0x2580`, and prints the result via
`printf("...RESULT: %s...")`.

> The Vigenère-looking string was a **red herring** — the real output path is the
> RC4 decryption triggered by passing the MD5 check.

---

## 3. Cracking the key

```bash
hashcat -m 0 -a 0 <md5hash> /usr/share/wordlists/rockyou.txt \
        -r /usr/share/john/rules/d3ad0ne.rule --force
```

Result:

```
f9586bf7ef09972d7daeb53f2ce12ff1 : Hackster
```

The key is **`Hackster`**.

---

## 4. Running it

```bash
printf 'Hackster\n' | ./Critical_db
```

```
>> Input Emergency Bypass Key: [AUTHENTICATED] Welcome, Cyan.
--- SESSION RECOVERY COMPLETE ---
STATUS: Decryption Successful
RESULT: HKSTR{MIRA_HQ-CENTRAL_DB_RECOVERED}
```

---

## 5. Flag

```
HKSTR{MIRA_HQ-CENTRAL_DB_RECOVERED}
```

---

## 6. Takeaways

* Obfuscation ≠ encryption: an XOR-with-a-single-byte constant is instantly
  recoverable (the `0x42` here).
* Password checks that compare a **hash of user input** are only as strong as the
  underlying password — crack the hash, don't fight the binary.
* Watch for red-herring computations (the Vigenère path); identify which branch
  actually prints output.

---

## Tools used

`strings`, disassembler (objdump/Ghidra-style), `hashcat`, `rockyou.txt`, `d3ad0ne.rule`.

*Write-up by **Priyank Rastogi**.*