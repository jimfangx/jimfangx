#!/usr/bin/env bash

# System setup for Linux machines where I have sudo (Debian/Ubuntu).
# Run in addition to linux-bootstrap.sh, in any order. Safe to re-run.
#
#   ./linux-sudo-bootstrap.sh
#   curl -fsSL https://raw.githubusercontent.com/jimfangx/jimfangx/main/linux-sudo-bootstrap.sh | bash

set -euo pipefail

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
skip() { printf '    already done: %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo not found. Run as root or use linux-bootstrap.sh only" >&2
    exit 1
  fi
  SUDO="sudo"
  sudo -v  # ask for the password once, up front
fi

# ===  Packages  ===

log "build-essential, bubblewrap, apparmor-profiles"
$SUDO apt-get update
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential bubblewrap apparmor-profiles

# ===  bwrap AppArmor profile  ===

# Ubuntu >= 23.10 blocks unprivileged user namespaces (kernel.apparmor_restrict_unprivileged_userns),
# which bwrap needs. This profile allows them for bwrap only
BWRAP_PROFILE='abi <abi/4.0>,
include <tunables/global>

profile bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,
  include if exists <local/bwrap>
}'

log "AppArmor profile for bwrap"
if [ "$($SUDO cat /etc/apparmor.d/bwrap 2>/dev/null)" = "$BWRAP_PROFILE" ]; then
  skip "/etc/apparmor.d/bwrap"
else
  printf '%s\n' "$BWRAP_PROFILE" | $SUDO tee /etc/apparmor.d/bwrap >/dev/null
fi
if command -v aa-enabled >/dev/null 2>&1 && aa-enabled -q 2>/dev/null; then
  $SUDO apparmor_parser -r /etc/apparmor.d/bwrap
  if [ -n "$SUDO" ]; then
    if bwrap --ro-bind / / --dev /dev true 2>/dev/null; then
      echo "    bwrap works without sudo"
    else
      warn "bwrap still fails without sudo: $(bwrap --ro-bind / / --dev /dev true 2>&1 || true)"
    fi
  fi
else
  warn "AppArmor is not enabled, profile written but not loaded"
fi

# ===  /scratch  ===

# 1777 = everyone can create, read and enter. Sticky bit (the 1): only the owner of a
# file/folder (or root) can delete or rename it. Folders users create get their own
# permissions (755/775 with default umask), so others can read but not write in them
log "/scratch"
$SUDO mkdir -p /scratch
$SUDO chown root:root /scratch
$SUDO chmod 1777 /scratch
stat -c '    %A %U:%G %n' /scratch

log "Done"
