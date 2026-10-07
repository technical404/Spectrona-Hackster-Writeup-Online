# CTF Report — `zips.zip` (Per-file Password Mapping)

**Category:** Crypto / Forensics
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{j0hny_j0hny_wh0_st0le_the_flag_fr0m_the_zip}`

---

## TL;DR

`zips.zip` contains **50 tiny password-protected 7z archives** (`1.7z` …
`50.7z`). Each archive's password is a specific **word from an accompanying
wordlist**, and the mapping is determined by brute-forcing a candidate list
(529 words) against each file. Extracting them in order reveals the flag.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `zips.zip` (same folder as this report) |
| Size | `22,663` bytes |
| Contents | `1.7z` … `50.7z` (50 archives, ~206 bytes each, encrypted headers) |
| Extra | wordlist (529 words) |

---

## 2. Approach

Each small archive has an **encrypted header** (so you can't even list contents
without the password). The winning strategy: test every wordlist entry against
every archive and record which password opens which file.

```bash
# for each archive, try each candidate with 7z (scripted):
for f in *.7z; do
  while read -r w; do
    if 7z t -p"$w" "$f" >/dev/null 2>&1; then echo "$f -> $w"; fi
  done < words.txt
done
```

### Partial mapping (confirmed)

| Archive | Password | Archive | Password |
|---|---|---|---|
| `1.7z` | `interface` | `13.7z` | `passcode` |
| `2.7z` | `gateway` | `14.7z` | `mutex` |
| `10.7z` | `zulu` | `15.7z` | `hook` |
| `11.7z` | `password5` | `16.7z` | `firewall` |
| `12.7z` | `archive123` | `17.7z` | `checkout` |
| `18.7z` | `alias` | `19.7z` | `agent` |
| `20.7z` | `write` | `21.7z` | `asdfgh` |
| `22.7z` | `autoscale` | `23.7z` | `access` |
| `24.7z` | `target` | … | … |

(529 candidates tested; a "MATCH" list of per-file passwords is produced.)

---

## 3. Assembling the flag

Extracting the archives yields fragments that, concatenated (note `2.txt` carries
a trailing newline, hence the line break in the raw assembly), spell:

```
HKSTR{j0hny_j0hny_wh0_st0le_the_flag_fr0m_the_zip}
```

("Johnny Johnny, who stole the flag from the zip" — a nursery-rhyme joke about
extracting from many small archives.)

---

## 4. Flag

```
HKSTR{j0hny_j0hny_wh0_st0le_the_flag_fr0m_the_zip}
```

---

## 5. Takeaways

* When you have **many** small encrypted archives and a wordlist, brute-force the
  **cross-product** (each word × each archive) — encrypted headers mean you can't
  shortcut by listing contents.
* Keep an eye on **trailing newlines** in extracted fragments when reassembling;
  they can break exact-string checks.

---

## Tools used

`7z`, `zip`, a wordlist (529 entries), shell/Python scripting.

*Write-up by **Priyank Rastogi**.*