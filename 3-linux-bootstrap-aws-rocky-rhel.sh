#!/usr/bin/env bash
# AWS EC2 Rocky Linux 9/10 bootstrap: AWS CLI credentials, user password,
# Mountpoint for S3, Amazon EFS utils, GNOME + Amazon DCV remote desktop, Docker.
# Run in addition to the generic linux-bootstrap / linux-sudo-bootstrap scripts.
# Run as a regular user with sudo privileges; designed to be safe to re-run.
#
#   chmod +x 3-linux-bootstrap-aws-rocky.sh
#   ./3-linux-bootstrap-aws-rocky.sh
#
# Prompts for AWS credentials (unless already configured) and a password, then
# continues unattended. It does not mount EFS or S3 buckets automatically.

set -euo pipefail
log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
skip() { printf '    already done: %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
dnf_install() { sudo dnf install -y "$@"; }
is_installed() { rpm -q --quiet "$1"; }
has_tty() { ( : </dev/tty ) 2>/dev/null; }

# install_root_file PATH MODE <<EOF ... EOF: write stdin to a root-owned file if changed.
install_root_file() {
  local file="$1" mode="$2" content
  content="$(cat)"
  sudo mkdir -p "$(dirname "$file")"
  if [ "$(sudo cat "$file" 2>/dev/null)" = "$content" ]; then
    skip "$file"
  else
    printf '%s\n' "$content" | sudo tee "$file" >/dev/null
    echo "    wrote $file"
  fi
  sudo chown root:root "$file"
  sudo chmod "$mode" "$file"
}

[ "$(id -u)" -ne 0 ] || fail "Run as your regular user (for EC2, often 'rocky'), not root."
USER_NAME="$(id -un)"
# shellcheck disable=SC1091
. /etc/os-release
[ "${ID:-}" = "rocky" ] || fail "This script is for Rocky Linux, not ${PRETTY_NAME:-unknown}."
ROCKY_MAJOR="${VERSION_ID%%.*}"
case "$ROCKY_MAJOR" in
  9|10) ;;
  *) fail "This script supports Rocky Linux 9 and 10, not ${VERSION_ID:-unknown}." ;;
esac
case "$(uname -m)" in
  x86_64)         S3_ARCH="x86_64"; DCV_ARCH="x86_64" ;;
  aarch64|arm64)  S3_ARCH="arm64";  DCV_ARCH="aarch64" ;;
  *) fail "Unsupported architecture: $(uname -m)" ;;
esac

# Authenticate to sudo once and refresh its timestamp during long builds.
sudo -n true 2>/dev/null || sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
WORK_DIR="$(mktemp -d)"
chmod 755 "$WORK_DIR"
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; rm -rf "$WORK_DIR"' EXIT

# === a) AWS CLI v2, interactive credential/password setup ===
log "Base packages"
dnf_install ca-certificates curl unzip tar

log "AWS CLI v2"
if command -v aws >/dev/null 2>&1; then
  skip "$(aws --version 2>&1)"
else
  curl -fsSL -o "$WORK_DIR/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip"
  unzip -q "$WORK_DIR/awscliv2.zip" -d "$WORK_DIR"
  sudo "$WORK_DIR/aws/install"
fi

log "aws configure"
if aws configure get aws_access_key_id >/dev/null 2>&1; then
  skip "AWS CLI default-profile credentials"
elif aws sts get-caller-identity --output text >/dev/null 2>&1; then
  skip "AWS credentials available from environment/EC2 instance role"
elif ! has_tty; then
  warn "No terminal for prompts; skipping. Use an EC2 IAM role or run 'aws configure'."
else
  warn "An EC2 IAM instance role is preferable to persistent access keys on disk."
  aws configure </dev/tty
fi

# A local password is used for DCV login with system authentication.
log "Password for $USER_NAME"
passwd_state="$(sudo passwd -S "$USER_NAME" | awk '{print $2}')"
if [[ "$passwd_state" == "P" || "$passwd_state" == "PS" ]]; then
  skip "password is set"
elif ! has_tty; then
  warn "No terminal for prompts; set a DCV login password with: sudo passwd $USER_NAME"
else
  until sudo passwd "$USER_NAME" </dev/tty; do
    echo "    try again"
  done
fi

# === b) Mountpoint for Amazon S3 ===
log "Mountpoint for Amazon S3"
if is_installed mount-s3; then
  skip "mount-s3"
else
  curl -fsSL -o "$WORK_DIR/mount-s3.rpm" \
    "https://s3.amazonaws.com/mountpoint-s3-release/latest/$S3_ARCH/mount-s3.rpm"
  dnf_install "$WORK_DIR/mount-s3.rpm"
fi

# === c, d) EFS mount helper, built from source as RPM ===
log "Amazon EFS utils"
if is_installed amazon-efs-utils; then
  skip "amazon-efs-utils"
else
  # EFS Utils 3.x needs Rust 1.94.1+ (Rocky's packaged Rust may be older).
  # Building without RPM's system_rust condition uses rustup from this user.
  dnf_install git binutils pkgconf-pkg-config openssl-devel gettext make gcc gcc-c++ \
    cmake wget perl golang rpm-build systemd python3 nfs-utils stunnel which
  if [ "$ROCKY_MAJOR" = "10" ]; then
    # AWS-LC FIPS builds with clang on RHEL/Rocky 10 (GCC 14+ is unsupported).
    dnf_install clang
    export CC=clang CXX=clang++
    export CFLAGS="-Wno-unused-command-line-argument"
    export CXXFLAGS="-Wno-unused-command-line-argument"
  fi
  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    "$HOME/.cargo/bin/rustup" update stable
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
