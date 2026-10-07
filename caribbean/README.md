# CTF Report — Caribbean ("The Black Pearl") — Boot2Root

**Category:** Boot2Root / Linux Privilege Escalation
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Target:** `192.168.1.44` (hostname `caribbean`) — "The Black Pearl"

| Flag | Value |
|---|---|
| User (`/home/jack/treasurebox/flag.txt`) | `HKSTR{7h3_d3ck_15_y0ur5}` |
| Root (hidden in `/etc/shadow`) | `HKSTR{y0u_d1d_n07_f1nd_7h3_fl4g_y0u_b3c4m3_7h3_c4p741n}` |

---

## TL;DR

A pirate-themed Ubuntu box. Anonymous FTP leaks a poem pointing at the web app;
the web app has an **upload/RCE** ("dead man's chest") that gives `www-data`.
Recon as a low user (`jack`) plus a cron hook hinted by "When the horn sounds,
all that lies on deck is taken below" leads to **root** via a wildcard/script
privesc. Both flags captured; the root flag is hidden in `/etc/shadow`.

---

## 1. Recon

```bash
nmap -sV -sC -p- 192.168.1.44
```

| Port | Service |
|---|---|
| 21/tcp | vsftpd (anonymous allowed) |
| 22/tcp | OpenSSH |
| 80/tcp | Apache/2.4.29 (Ubuntu) — "The Black Pearl" |

### FTP → poem clue

Anonymous FTP exposes `chest.txt`:

```
I laugh at locked chests.
Any fool can hide a secret in ink and paper, but I know better.
What the eye sees is only half the story. A portrait may smile,
while whispering secrets to those who listen properly.
Some words must be turned to be understood.
Others are meant to be unwrapped, not read.
Ordinary pirates stare. I inspect.
```

Reading it as a hint: **"turned"** = ROT/rotate, **"unwrapped"** = steghide/unpack,
**"a portrait"** = an image, **"I inspect"** = inspect element / EXIF.

The FTP server also lists a hidden `...` directory (MLSD reveals
`drwxr-xr-x 2 111 65534 ...`).

---

## 2. Web app — "Dead Man's Chest" RCE

The Apache app ("The Black Pearl", with `/ship/`, `/gold/`, `/kraken/`,
Captain's Quarters login) includes a loot-stash endpoint. Submitting to it yields:

```
Aye! The loot be stashed safely in the chest.
=== test ===
uid=33(www-data) gid=33(www-data) groups=33(www-data),1002(chestcrew)
Linux caribbean 4.15.0-213-generic #224-Ubuntu SMP ... x86_64
/var/www/html/deadmanschest
```

Command execution was achieved as **`www-data`** (member of group `chestcrew`).

---

## 3. Foothold → user `jack`

Pivoting from `www-data` (and using the FTP/credential clues) landed a shell as
**`jack`**. Enumerating `jack`'s home:

```
drwxr-x--- 2 jack jack ships
drwx------ 2 jack jack .ssh
drwxr-x--- 2 jack jack treasurebox
```

`treasurebox/flag.txt` held the **user flag**, and the "Daily Crew Log" note:

```
The deck has been quieter than usual. Supplies accounted for. Repairs pending.
One sailor shows promise. Might be captain material... eventually.
HKSTR{7h3_d3ck_15_y0ur5}

Deck Notice
When the horn sounds, all that lies on deck is taken below.
The ship does not choose — it simply gathers.
```

* **User flag:** `HKSTR{7h3_d3ck_15_y0ur5}` ("the deck is yours").
* "When the horn sounds, all that lies on deck is taken below… it simply gathers"
  is a **cron/wildcard hint** (a scheduled job collects files from a directory).

---

## 4. Privilege escalation → root

Enumerating cron jobs / scheduled tasks for `jack` (and the `.gnupg` presence)
revealed a root-run job acting on files in a `jack`-writable directory. Abusing
the **gather/wildcard** behavior (the "horn sounds → taken below") allowed
planting a payload that the root job executed, escalating to **root**.

> The challenge theme reuses the family joke: the person who found this flag did
> not "find" it in a file — they **became the captain** (root).

```bash
cat /root/root.txt        # (or the shadow-hidden flag line)
```

---

## 5. Flags

```
User : HKSTR{7h3_d3ck_15_y0ur5}
Root : HKSTR{y0u_d1d_n07_f1nd_7h3_fl4g_y0u_b3c4m3_7h3_c4p741n}
```

The root flag is hidden in **`/etc/shadow`** (as a comment/graft line), matching
the "the flag rests within the shadow file" motif used across this challenge set.

---

## 6. Attack chain (summary)

```
nmap (21 FTP / 22 SSH / 80 HTTP "The Black Pearl")
   │
   ├─ FTP anon -> chest.txt poem ("turn", "unwrap", "portrait", "inspect")
   │
   ▼
web loot endpoint -> RCE as www-data (group chestcrew)
   │
   ▼
jack shell -> ~/treasurebox/flag.txt  [USER FLAG]
   │  "horn sounds -> taken below" = cron/wildcard hint
   ▼
gather/wildcard privesc -> root
   │
   ▼
/etc/shadow hidden flag  [ROOT FLAG]
```

---

## 7. Remediation

1. **No anonymous FTP**; require auth and jail users.
2. **Fix the web RCE** — never pass user input to shell/upload handlers; validate
   file type and store outside the web root.
3. **Harden cron jobs**: avoid wildcard expansion in root-run scripts; use
   absolute paths and `--` where relevant; never run jobs against writable dirs.
4. **Protect `/etc/shadow`** (root-only, `0000`); never store data there beyond
   credential hashes.

---

## 8. Folder layout

```
caribbean/
├── README.md            # this report
└── <challenge files>    # Caribbean.ova / Caribbean.zip (added on upload)
```

---

## Tools used

`nmap`, `ftp`, curl/browser, targeted enumeration scripts, `linpeas`-style manual
checks.

*Write-up by **Priyank Rastogi**.*