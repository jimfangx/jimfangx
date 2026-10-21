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
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  git clone --depth 1 https://github.com/aws/efs-utils.git "$WORK_DIR/efs-utils"
  (cd "$WORK_DIR/efs-utils" && make rpm-without-system-rust)
  efs_rpms=("$WORK_DIR"/efs-utils/build/amazon-efs-utils-*.rpm)
  [ -f "${efs_rpms[0]}" ] || fail "Could not find the built amazon-efs-utils RPM."
  dnf_install "${efs_rpms[@]}"
fi

# === e) GNOME desktop, required for DCV ===
# Unlike the original Ubuntu script (whose desktop step was commented out),
# install GNOME when missing: minimal Rocky EC2 images do not contain it.
log "GNOME desktop (Server with GUI)"
if command -v gnome-session >/dev/null 2>&1 && command -v gdm >/dev/null 2>&1; then
  skip "GNOME and GDM"
else
  sudo dnf group install -y "Server with GUI"
fi

if [ "$ROCKY_MAJOR" = "10" ]; then
  # Amazon DCV 2026.0 on Rocky 10 uses Wayland GNOME virtual sessions.
  # AWS requires a running graphical.target/GDM for this mode.
  sudo systemctl set-default graphical.target
  sudo systemctl enable --now gdm
  sudo systemctl start graphical.target
fi

# === f) Amazon DCV: X11 on Rocky 9, Wayland on Rocky 10 ===
log "Amazon DCV (el${ROCKY_MAJOR}, $DCV_ARCH)"
if is_installed nice-dcv-server && is_installed nice-dcv-web-viewer && \
   { [ "$ROCKY_MAJOR" = "10" ] || is_installed nice-xdcv; }; then
  skip "Amazon DCV server, web viewer, and virtual-session components"
else
  sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
  curl -fsSL -o "$WORK_DIR/nice-dcv.tgz" \
    "https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-el${ROCKY_MAJOR}-${DCV_ARCH}.tgz"
  mkdir -p "$WORK_DIR/dcv"
  tar -xzf "$WORK_DIR/nice-dcv.tgz" -C "$WORK_DIR/dcv"
  shopt -s nullglob
  dcv_server=("$WORK_DIR"/dcv/nice-dcv-*/nice-dcv-server-*.rpm)
  dcv_web=("$WORK_DIR"/dcv/nice-dcv-*/nice-dcv-web-viewer-*.rpm)
  dcv_x11=("$WORK_DIR"/dcv/nice-dcv-*/nice-xdcv-*.rpm)
  shopt -u nullglob
  [ "${#dcv_server[@]}" -eq 1 ] && [ "${#dcv_web[@]}" -eq 1 ] || \
    fail "Could not locate DCV server/web viewer RPMs in the archive."
  if [ "$ROCKY_MAJOR" = "9" ]; then
    [ "${#dcv_x11[@]}" -eq 1 ] || fail "Could not locate DCV X11 virtual-session RPM."
    dnf_install "${dcv_server[@]}" "${dcv_web[@]}" "${dcv_x11[@]}"
  else
    # Rocky 10's Wayland DCV packages do not include nice-xdcv.
    dnf_install "${dcv_server[@]}" "${dcv_web[@]}"
  fi
fi
if id dcv >/dev/null 2>&1 && getent group video >/dev/null 2>&1; then
  sudo usermod -aG video dcv
fi
sudo systemctl enable --now dcvserver

# An on-boot timer recreates the virtual session after it disappears.
log "DCV 'desktop' session (systemd timer)"
if [ "$ROCKY_MAJOR" = "9" ]; then
  install_root_file /usr/local/bin/dcv-gnome-session 755 <<'EOF'
#!/usr/bin/env bash
# Rocky 9 / X11: start GNOME with its own D-Bus session inside the DCV X server.
mkdir -p "$HOME/.cache"
exec >"$HOME/.cache/dcv-gnome-session.log" 2>&1
set -x
unset DBUS_SESSION_BUS_ADDRESS SESSION_MANAGER
export PATH=/usr/bin:/bin
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export GNOME_SHELL_SESSION_MODE=gnome
exec /usr/bin/dbus-run-session -- /usr/bin/gnome-session --session=gnome
EOF
fi

# Generate a root-owned session script. %q ensures the user argument is escaped.
printf -v user_quoted '%q' "$USER_NAME"
if [ "$ROCKY_MAJOR" = "9" ]; then
  session_args="--user $user_quoted --init /usr/local/bin/dcv-gnome-session"
else
  session_args=""
fi
install_root_file /usr/local/bin/dcv-ensure-session 755 <<EOF
#!/usr/bin/env bash
# Create the user's DCV virtual session if it is missing.
set -euo pipefail
if dcv list-sessions | grep -qF "Session: 'desktop'"; then
  exit 0
fi
exec dcv create-session --type virtual --owner $user_quoted $session_args desktop
EOF
install_root_file /etc/systemd/system/dcv-desktop-session.service 644 <<'EOF'
[Unit]
Description=Create Amazon DCV "desktop" virtual session if missing
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
if ! sudo systemctl start dcv-desktop-session.service; then
  warn "DCV session could not start yet. After the recommended reboot, the timer will retry it."
fi
sudo dcv list-sessions || warn "DCV session listing failed; check sudo systemctl status dcvserver"

# If firewalld is active, explicitly allow DCV's HTTPS port. The EC2 security
# group must separately permit TCP 8443 from the intended client IPs.
if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
  log "Firewalld: DCV TCP 8443"
  if sudo firewall-cmd --query-port=8443/tcp >/dev/null 2>&1; then
    skip "8443/tcp in firewalld"
  else
    sudo firewall-cmd --permanent --add-port=8443/tcp
    sudo firewall-cmd --reload
  fi
fi

# === g) Docker Engine ===
log "Docker Engine"
if is_installed docker-ce; then
  skip "docker-ce"
else
  conflicts=()
  for package in docker docker-client docker-client-latest docker-common docker-latest \
                 docker-latest-logrotate docker-logrotate docker-engine docker.io \
                 podman-docker containerd runc; do
    if is_installed "$package"; then
      conflicts+=("$package")
    fi
  done
  if [ "${#conflicts[@]}" -gt 0 ]; then
    sudo dnf remove -y "${conflicts[@]}"
  fi
  dnf_install dnf-plugins-core
  if [ ! -f /etc/yum.repos.d/docker-ce.repo ]; then
    sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  fi
  dnf_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
if [ "$ROCKY_MAJOR" = "10" ]; then
  # Current RHEL/Rocky 10 kernels sometimes need this package for xt_addrtype.
  dnf_install kernel-modules-extra
  sudo modprobe xt_addrtype 2>/dev/null || warn "xt_addrtype unavailable in the current kernel; reboot may be required for Docker."
fi
sudo groupadd -f docker
sudo usermod -aG docker "$USER_NAME"
if ! sudo systemctl enable --now docker; then
  warn "Docker did not start. If kernel modules were installed, reboot and try: sudo systemctl start docker"
fi

# === Done ===
# Best effort: get instance public IP using IMDSv2 (otherwise print placeholder).
imds_token="$(curl -fsS -m 2 -X PUT http://169.254.169.254/latest/api/token \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' 2>/dev/null || true)"
public_ip="$(curl -fsS -m 2 -H "X-aws-ec2-metadata-token: $imds_token" \
  http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
log "Done"
echo "    Docker: log out and in again (or run: newgrp docker) for group access."
echo "    DCV desktop: https://${public_ip:-<instance-public-ip>}:8443 (user: $USER_NAME)"
echo "    Allow inbound TCP 8443 from your IP in the EC2 security group."
echo "    The 'desktop' virtual session is checked/recreated once per minute."
echo "    Reboot after initial GNOME/DCV/kernel-module installation: sudo reboot"
echo "    EFS and S3 mountpoints are not configured by this script."

