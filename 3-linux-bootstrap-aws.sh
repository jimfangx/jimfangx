#!/usr/bin/env bash

# AWS EC2 (Ubuntu 24.04) setup: AWS CLI credentials, user password, Mountpoint for S3,
# EFS utils, Ubuntu desktop + Amazon DCV remote desktop, Docker. Needs sudo.
# Run in addition to linux-bootstrap.sh / linux-sudo-bootstrap.sh. Safe to re-run.
#
#   ./linux-bootstrap-aws.sh
#   curl -fsSL https://raw.githubusercontent.com/jimfangx/jimfangx/main/linux-bootstrap-aws.sh | bash
#
# Asks for input first (AWS credentials, password), then runs unattended.

set -euo pipefail

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
skip() { printf '    already done: %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }

apt_install() { sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; }
is_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
has_tty() { ( : </dev/tty ) 2>/dev/null; }

# install_root_file PATH MODE <<EOF ... EOF: write stdin to a root-owned file, if changed
install_root_file() {
  local file="$1" mode="$2" content
  content="$(cat)"
  if [ "$(sudo cat "$file" 2>/dev/null)" = "$content" ]; then
    skip "$file"
  else
    printf '%s\n' "$content" | sudo tee "$file" >/dev/null
    echo "    wrote $file"
  fi
  sudo chmod "$mode" "$file"
}

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: run as your normal user (e.g. ubuntu), not root. It uses sudo where needed" >&2
  exit 1
fi
USER_NAME="$(id -un)"

. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "24.04" ]; then
  warn "Made for Ubuntu 24.04 (DCV packages are for 24.04), this is ${PRETTY_NAME:-unknown}"
fi

case "$(uname -m)" in
  x86_64)        S3_ARCH="x86_64"; DCV_ARCH="x86_64" ;;
  aarch64|arm64) S3_ARCH="arm64";  DCV_ARCH="aarch64" ;;
  *) echo "ERROR: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

# Ask for sudo password once, unless sudo doesn't need one, and keep sudo alive during
# long installs. Not just `sudo -v`: it asks for a password unless ALL matching sudoers
# rules are NOPASSWD (e.g. on AWS, "ubuntu ALL=(ALL) NOPASSWD:ALL" plus "%sudo ALL=(ALL:ALL) ALL")
sudo -n true 2>/dev/null || sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

WORK_DIR="$(mktemp -d)"
chmod 755 "$WORK_DIR"  # so apt's sandbox user can read local .deb files
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; rm -rf "$WORK_DIR"' EXIT

# ===  a) Input: AWS credentials, user password  ===

log "AWS CLI"
if command -v aws >/dev/null 2>&1; then
  skip "$(aws --version)"
else
  apt_install unzip
  curl -fsSL -o "$WORK_DIR/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
  unzip -q "$WORK_DIR/awscliv2.zip" -d "$WORK_DIR"
  sudo "$WORK_DIR/aws/install"
fi

log "aws configure"
if aws configure get aws_access_key_id >/dev/null 2>&1; then
  skip "credentials for default profile"
elif ! has_tty; then
  warn "No terminal to prompt on, skipping. Run 'aws configure' yourself"
else
  aws configure </dev/tty
fi

# Password is needed to log in to the DCV remote desktop
log "Password for $USER_NAME"
if [ "$(sudo passwd -S "$USER_NAME" | awk '{ print $2 }')" = "P" ]; then
  skip "password is set"
elif ! has_tty; then
  warn "No terminal to prompt on, skipping. Run 'sudo passwd $USER_NAME' yourself"
else
  until sudo passwd "$USER_NAME" </dev/tty; do
    echo "    try again"
  done
fi

# ===  b) Mountpoint for Amazon S3  ===

log "Mountpoint for Amazon S3"
if is_installed mount-s3; then
  skip "mount-s3"
else
  curl -fsSL -o "$WORK_DIR/mount-s3.deb" "https://s3.amazonaws.com/mountpoint-s3-release/latest/$S3_ARCH/mount-s3.deb"
  apt_install "$WORK_DIR/mount-s3.deb"
fi

# ===  c, d) Amazon EFS utils, built from source  ===

log "Amazon EFS utils"
if is_installed amazon-efs-utils; then
  skip "amazon-efs-utils"
else
  # Build deps from efs-utils INSTALL.md, plus Go for the AWS-LC FIPS module.
  # Rust comes from rustup: efs-utils needs Rust >= 1.94.1, apt's rustc on 24.04 is 1.75
  sudo apt-get update
  apt_install git binutils pkg-config libssl-dev gettext make gcc g++ cmake wget perl golang-go
  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    "$HOME/.cargo/bin/rustup" update stable
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  git clone --depth 1 https://github.com/aws/efs-utils.git "$WORK_DIR/efs-utils"
  (cd "$WORK_DIR/efs-utils" && ./build-deb.sh)
  apt_install "$WORK_DIR"/efs-utils/build/amazon-efs-utils*.deb
fi

# ===  f) Ubuntu desktop  ===

# Disabled. Note: the DCV session below starts GNOME (gnome-session), which comes with it
# log "Ubuntu desktop"
# if is_installed ubuntu-desktop; then
#   skip "ubuntu-desktop"
# else
#   sudo apt-get update
#   apt_install ubuntu-desktop
# fi

# ubuntu-desktop (via ubuntu-settings) installs /usr/lib/netplan/00-network-manager-all.yaml, which
# hands all network cards to NetworkManager at boot. On EC2 that can leave the card without DNS.
# Keep EC2's default (systemd-networkd), by shadowing that file. Takes effect on next reboot
if [ -e /usr/lib/netplan/00-network-manager-all.yaml ]; then
  log "Keep network card on systemd-networkd"
  install_root_file /etc/netplan/00-network-manager-all.yaml 600 <<'EOF'
# Overrides /usr/lib/netplan/00-network-manager-all.yaml (from ubuntu-desktop), which hands
# all network cards to NetworkManager. Keep EC2's default, systemd-networkd
network:
  version: 2
  renderer: networkd
EOF
  sudo netplan generate
fi

# Installing ubuntu-desktop moves the network card from systemd-networkd to NetworkManager,
# which can leave it without DNS servers until a reboot. Set the VPC DNS server on it
# (until reboot). 192.168.0.2 = DNS of VPC 192.168.0.0/16 (VPC base + 2); 169.254.169.253 works in any VPC
VPC_DNS="192.168.0.2"
log "DNS server $VPC_DNS"
net_card="$(ip route show default | awk '{ print $5; exit }')"
if [ -z "$net_card" ]; then
  warn "No default route, not setting DNS"
elif sudo resolvectl dns "$net_card" "$VPC_DNS" && sudo resolvectl default-route "$net_card" yes; then
  echo "    set on $net_card"
else
  warn "Cannot set DNS on $net_card"
fi

# ===  g-l) Amazon DCV remote desktop  ===

log "Amazon DCV"
if is_installed nice-dcv-server; then
  skip "nice-dcv-server"
else
  curl -fsSL -o "$WORK_DIR/nice-dcv.tgz" "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2404-$DCV_ARCH.tgz"
  tar -xzf "$WORK_DIR/nice-dcv.tgz" -C "$WORK_DIR"
  dcv_dir="$(echo "$WORK_DIR"/nice-dcv-*-ubuntu2404-"$DCV_ARCH")"
  apt_install "$dcv_dir"/nice-dcv-server_*.deb "$dcv_dir"/nice-dcv-web-viewer_*.deb "$dcv_dir"/nice-xdcv_*.deb
fi
sudo usermod -aG video dcv
sudo systemctl enable --now dcvserver

# Keep a virtual session "desktop" running: a timer creates it at boot, and again within
# a minute whenever it's gone (e.g. after logging out of GNOME)
log "DCV session 'desktop' (systemd timer)"
install_root_file /usr/local/bin/dcv-gnome-session 755 <<'EOF'
#!/bin/bash
# DCV virtual session init: start GNOME on X11 with its own D-Bus session
mkdir -p "$HOME/.cache"
exec > "$HOME/.cache/dcv-gnome-session.log" 2>&1
set -x
unset DBUS_SESSION_BUS_ADDRESS SESSION_MANAGER
export PATH=/usr/bin:/bin
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export GNOME_SHELL_SESSION_MODE=ubuntu
exec /usr/bin/dbus-run-session -- /usr/bin/gnome-session --session=ubuntu
EOF
install_root_file /usr/local/bin/dcv-ensure-session 755 <<EOF
#!/bin/sh
# Create DCV virtual session "desktop" for $USER_NAME, unless it already exists
set -eu
if dcv list-sessions | grep -qF "Session: 'desktop'"; then
  exit 0
fi
exec dcv create-session --type virtual --owner $USER_NAME --user $USER_NAME \\
  --init /usr/local/bin/dcv-gnome-session desktop
EOF
install_root_file /etc/systemd/system/dcv-desktop-session.service 644 <<'EOF'
[Unit]
Description=Create Amazon DCV virtual session "desktop" if missing
After=dcvserver.service
Requires=dcvserver.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/dcv-ensure-session
EOF
install_root_file /etc/systemd/system/dcv-desktop-session.timer 644 <<'EOF'
[Unit]
Description=Keep Amazon DCV virtual session "desktop" running

[Timer]
OnBootSec=20s
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now dcv-desktop-session.timer
sudo systemctl start dcv-desktop-session.service
sudo dcv list-sessions

# ===  m) Docker  ===

log "Docker"
if is_installed docker-ce; then
  skip "docker-ce"
else
  # Remove distro packages that conflict with Docker's own
  conflicts="$(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx \
    podman-docker containerd runc 2>/dev/null | cut -f1)"
  if [ -n "$conflicts" ]; then
    # shellcheck disable=SC2086
    sudo apt-get remove -y $conflicts
  fi

  # Add Docker's official GPG key
  sudo apt-get update
  apt_install ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  # Add the repository to Apt sources
  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  sudo apt-get update
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
sudo groupadd -f docker
sudo usermod -aG docker "$USER_NAME"

# ===  Done  ===

# Public IP from instance metadata (IMDSv2), for the DCV URL
imds_token="$(curl -fsS -m 2 -X PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)"
public_ip="$(curl -fsS -m 2 -H "X-aws-ec2-metadata-token: $imds_token" \
  http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"

log "Done"
echo "    Log out and back in (or run: newgrp docker) to use docker without sudo"
echo "    DCV desktop: https://${public_ip:-<instance-public-ip>}:8443 (log in as $USER_NAME,"
echo "    security group must allow TCP 8443). The 'desktop' session is recreated within a minute"
echo "    after a reboot or logout (dcv-desktop-session.timer)"

# Installing ubuntu-desktop moves the network card from systemd-networkd to NetworkManager.
# Until a reboot, the card can end up with no DNS servers ("Temporary failure in name resolution")
if ! getent hosts github.com >/dev/null 2>&1; then
  warn "DNS lookups fail. Reboot to fix (sudo reboot). To fix until then:"
  warn "  sudo resolvectl dns <card, e.g. ens5> 169.254.169.253 && sudo resolvectl default-route <card> yes"
elif [ -f /var/run/reboot-required ]; then
  warn "Reboot required to finish installs (sudo reboot), e.g. network handover to NetworkManager"
fi
