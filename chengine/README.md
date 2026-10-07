# CTF Report — `chengine.exe` Binary Analysis & GitHub Token Extraction

**Category:** Reverse Engineering / Credential Recovery
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Environment:** Authorized CTF / lab exercise

---

## TL;DR

A Windows executable `chengine.exe` (bundled in this repository) is a
**PyInstaller-packed Python 3.9 application**. Unpacking it recovered the full
Python source, in which a **GitHub Personal Access Token (PAT)** was hard-coded.
The token is used by the app as the credential for a **GitHub Gist** that acts as
a remote user database (`dbase.csv`).

> The token value is **masked** throughout this repository. The full value is
> kept out of version control in a local, git-ignored file (see
> `secrets.local.txt`).

---

## 1. Artifact identification

| Property | Value |
|---|---|
| Path | `chengine.exe` (same directory as this report) |
| Size | `34,490,188` bytes |
| File type | `PE32+ executable for MS Windows 5.02 (GUI), x86-64, 7 sections` |
| Packer | PyInstaller (Python 3.9) |
| Bundled libs | `python39.dll`, `PYZ-00.pyz`, `base_library.zip` |
| MD5 | `c915862506174766e0104e52bf8bc400` |
| SHA-256 | `8f40e74befb55163893b4aaaf2fadaebaa1d330c4749f3b1dfb6425ec985f7eb` |

```bash
file chengine.exe
md5sum chengine.exe
sha256sum chengine.exe
```

The tail of the file contains the PyInstaller cookie magic `MEI\x0c\x0b\x0a\x0b\x0e`
and the string `PYZ-00.pyz`, confirming a PyInstaller archive.

---

## 2. Unpacking the PyInstaller archive

`pip install` was blocked by the environment (`PEP 668`, externally-managed),
so the extractor was run directly from its wheel:

```bash
# Run from the directory containing this report and chengine.exe
pip3 download pyinstxtractor-ng -d /tmp/pi --no-deps
python3 -m zipfile -e /tmp/pi/pyinstxtractor_ng-*-py3-none-any.whl /tmp/pi/wheel/
python3 /tmp/pi/wheel/pyinstxtractor_ng.py chengine.exe
```

Extraction output:

```
[+] Pyinstaller version: 2.1+
[+] Python version: 3.9
[+] Length of package: 34113356 bytes
[+] Found 1694 files in CArchive
[+] Found 782 files in PYZ archive
[+] Successfully extracted pyinstaller archive
```

The archive yielded readable Python sources under
`chengine.exe_extracted/`:

```
acset.py   cap.py   cmg.py   cred.py   gamelist.py
lead.py    login.py main.py  ofxo.py   signup.py
splash.py  xaim.py  yt.py
```

---

## 3. Token discovery

A recursive search for GitHub token patterns across the extracted sources:

```bash
grep -rInaE 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' .
```

recovered **two hard-coded classic PATs**:

| # | Masked token | Files |
|---|---|---|
| 1 | `ghp_N9B4...WBfZK` | `cap.py:22`, `lead.py:12`, `acset.py:23`, `ofxo.py:22`, `main.py:28`, `signup.py:25`, `login.py:29`, `cmg.py:12` |
| 2 | `ghp_xuz...C7qFl` | `xaim.py:10` |

Example (from `lead.py`):

```python
import gistyc
gist_api = gistyc.GISTyc(auth_token='ghp_<REDACTED>')
...
gist_list = gist_api.get_gists()
jm = gist_list[5]['files']['dbase.csv']['raw_url']
kt = pd.read_csv(jm)
```

### How the token is used

The application is an Among-Us-themed client that stores its **shared data
backend in a GitHub Gist** instead of a server:

* `lead.py` — reads the leaderboard from `gist_list[5]['files']['dbase.csv']`
  and renders the top 10 by `Online WINs`.
* `signup.py` / `login.py` / `cap.py` — read/write the same gist
  (`dbase.csv`) to register users and change passwords.
* `xaim.py` — a second token used for game data gists (`dev.csv`).

The gist CSV contains account data including a `password` column.

---

## 4. Impact

A **long-lived GitHub PAT was embedded in a distributed client binary**.
Because anything shipped to an endpoint is recoverable, any user who unpacks the
binary (as demonstrated here) obtains the token. With a valid token the
attacker can read and **modify** the shared gist — i.e. tamper with the entire
user database / leaderboard, and potentially any other resource the token's
scopes allow.

> Note: the tokens recovered during this exercise no longer authenticate
> (`HTTP 401 Bad credentials`), which is consistent with GitHub secret-scanning
> auto-revoking committed classic PATs.

---

## 5. Remediation

1. **Never embed secrets in client-side binaries.** Treat all shipped
   executables as public; a determined analyst can always extract embedded data.
2. **Rotate/revoke** any token that has ever been embedded or committed
   (the tokens here are already revoked).
3. **Move trust to a backend.** Use short-lived, per-user, least-privilege
   tokens minted by a server; never share one database token across all clients.
4. **Enable GitHub secret scanning + push protection** to catch leaked PATs.
5. **Least privilege:** the token only needed gist access — scope it (and prefer
   fine-grained tokens) so a leak cannot reach unrelated resources.

---

## 6. Repository layout

```
CTF_Reports/
└── chengine/
    ├── README.md          # this report
    ├── chengine.exe       # the analyzed sample (uploaded alongside this report)
    └── secrets.local.txt  # FULL token values — git-ignored, NOT committed
``` 

The shared `.gitignore` (which excludes `secrets.local.txt`) and the top-level
index `README.md` live at the repository root.

---

## 7. Tools used

* `file`, `md5sum`, `sha256sum`, `strings`, `grep`
* [`pyinstxtractor-ng`](https://pypi.org/project/pyinstxtractor-ng/) 2026.7.3

---

## Disclaimer

This analysis was performed in an authorized CTF / lab environment for
educational purposes. Token values are masked in this repository and stored
only in a local, untracked file.
