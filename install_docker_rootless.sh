#!/usr/bin/env bash
# install_docker_rootless.sh
# Auto-detects OS/arch and installs Docker (rootless) + Docker Compose v2 without sudo where possible.
# Requirements: a regular user account, internet access, and (for first-time host setup) one-time sudo
# to install prerequisite packages (uidmap, dbus-user-session, iptables, fuse-overlayfs, slirp4netns).
# After prerequisites are present, Docker itself runs fully rootless under your user.

set -euo pipefail

############################################
# Helpers
############################################
log()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m  %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if need_cmd sudo; then SUDO="sudo"; fi
fi

############################################
# Detect OS / Distro / Arch / Kernel
############################################
OS="$(uname -s)"
KERNEL="$(uname -r)"
ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
  x86_64|amd64)   ARCH="x86_64" ;;
  aarch64|arm64)  ARCH="aarch64" ;;
  armv7l|armhf)   ARCH="armhf" ;;
  *) die "Unsupported architecture: $ARCH_RAW" ;;
esac

[ "$OS" = "Linux" ] || die "Rootless Docker is only supported on Linux (detected: $OS)."

DISTRO="unknown"; DISTRO_LIKE=""; VERSION_ID=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
  VERSION_ID="${VERSION_ID:-}"
fi

log "OS=$OS  Distro=$DISTRO ($VERSION_ID)  Arch=$ARCH  Kernel=$KERNEL"

############################################
# Install prerequisites (one-time, needs sudo)
############################################
install_prereqs() {
  local pkgs_debian="uidmap dbus-user-session fuse-overlayfs slirp4netns iptables curl ca-certificates"
  local pkgs_rhel="shadow-utils dbus-daemon fuse-overlayfs slirp4netns iptables curl ca-certificates"
  local pkgs_arch="shadow dbus fuse-overlayfs slirp4netns iptables curl ca-certificates"
  local pkgs_suse="shadow dbus-1 fuse-overlayfs slirp4netns iptables curl ca-certificates"
  local pkgs_alpine="shadow-uidmap dbus fuse-overlayfs slirp4netns iptables curl ca-certificates"

  case "$DISTRO|$DISTRO_LIKE" in
    *debian*|*ubuntu*|ubuntu*|debian*)
      log "Installing prerequisites via apt"
      $SUDO apt-get update -y
      $SUDO apt-get install -y $pkgs_debian
      ;;
    *fedora*|fedora*)
      log "Installing prerequisites via dnf"
      $SUDO dnf install -y $pkgs_rhel
      ;;
    *rhel*|*centos*|*rocky*|*almalinux*|rhel*|centos*|rocky*|almalinux*)
      log "Installing prerequisites via yum/dnf"
      if need_cmd dnf; then $SUDO dnf install -y $pkgs_rhel
      else $SUDO yum install -y $pkgs_rhel; fi
      ;;
    *arch*|arch*|*manjaro*|manjaro*)
      log "Installing prerequisites via pacman"
      $SUDO pacman -Sy --noconfirm $pkgs_arch
      ;;
    *suse*|*opensuse*|opensuse*|suse*)
      log "Installing prerequisites via zypper"
      $SUDO zypper -n install $pkgs_suse
      ;;
    *alpine*|alpine*)
      log "Installing prerequisites via apk"
      $SUDO apk add --no-cache $pkgs_alpine
      ;;
    *)
      warn "Unknown distro ($DISTRO). Ensure these are installed: uidmap, dbus-user-session, fuse-overlayfs, slirp4netns, iptables, curl."
      ;;
  esac
}

############################################
# Ensure subuid / subgid for current user
############################################
ensure_subids() {
  local user; user="$(id -un)"
  if ! grep -q "^${user}:" /etc/subuid 2>/dev/null; then
    log "Adding ${user} to /etc/subuid"
    echo "${user}:100000:65536" | $SUDO tee -a /etc/subuid >/dev/null
  fi
  if ! grep -q "^${user}:" /etc/subgid 2>/dev/null; then
    log "Adding ${user} to /etc/subgid"
    echo "${user}:100000:65536" | $SUDO tee -a /etc/subgid >/dev/null
  fi
}

############################################
# Install Docker rootless (no sudo for this step)
############################################
install_rootless_docker() {
  log "Installing rootless Docker for user $(id -un)"
  if ! need_cmd curl; then die "curl is required."; fi

  # Official rootless installer
  curl -fsSL https://get.docker.com/rootless | sh

  # Persist PATH and DOCKER_HOST (guard against duplicate entries on re-run)
  local bashrc="${HOME}/.bashrc"
  local xdg="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if ! grep -q '# >>> Rootless Docker >>>' "$bashrc" 2>/dev/null; then
    {
      echo ''
      echo '# >>> Rootless Docker >>>'
      echo "export PATH=\"\$HOME/bin:\$PATH\""
      echo "export DOCKER_HOST=unix://${xdg}/docker.sock"
      echo '# <<< Rootless Docker <<<'
    } >> "$bashrc"
  fi

  export PATH="$HOME/bin:$PATH"
  export DOCKER_HOST="unix://${xdg}/docker.sock"
}

############################################
# Enable & start systemd user service (if available)
############################################
enable_user_service() {
  if need_cmd systemctl && systemctl --user show-environment >/dev/null 2>&1; then
    log "Enabling rootless docker user service"
    systemctl --user enable docker || true
    systemctl --user start docker  || true
    if need_cmd loginctl; then
      $SUDO loginctl enable-linger "$(id -un)" || true
    fi
  else
    warn "systemd --user not available; start daemon manually with: dockerd-rootless.sh &"
  fi
}

############################################
# Install Docker Compose v2 plugin (rootless, user-scoped)
############################################
install_compose() {
  log "Installing Docker Compose v2 (user-scoped CLI plugin)"
  local plugin_dir="${HOME}/.docker/cli-plugins"
  mkdir -p "$plugin_dir"

  local compose_arch
  case "$ARCH" in
    x86_64)  compose_arch="x86_64" ;;
    aarch64) compose_arch="aarch64" ;;
    armhf)   compose_arch="armv7" ;;
    *) die "Unsupported arch for Compose: $ARCH" ;;
  esac

  local latest
  latest="$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest \
            | grep -oE '"tag_name":\s*"v[^"]+"' | head -n1 | cut -d'"' -f4)"
  [ -n "$latest" ] || latest="v2.29.7"

  local url="https://github.com/docker/compose/releases/download/${latest}/docker-compose-linux-${compose_arch}"
  log "Downloading ${url}"
  curl -fsSL "$url" -o "${plugin_dir}/docker-compose"
  chmod +x "${plugin_dir}/docker-compose"
}

############################################
# Verify
############################################
verify() {
  log "Verifying installation"
  docker --version || warn "docker CLI not found in PATH yet (open a new shell)."
  docker compose version || warn "compose plugin not visible yet (open a new shell)."
  log "Try: docker run --rm hello-world"
}

############################################
# Main
############################################
main() {
  install_prereqs
  ensure_subids
  install_rootless_docker
  enable_user_service
  install_compose
  verify
  cat <<EOF

✅ Done. Open a new shell (or run: source ~/.bashrc) to pick up env vars.

Env set:
  PATH="\$HOME/bin:\$PATH"
  DOCKER_HOST=unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/docker.sock

Commands:
  docker info
  docker compose version
EOF
}

main "$@"
