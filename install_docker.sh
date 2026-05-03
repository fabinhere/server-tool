#!/usr/bin/env bash
# install_docker.sh
# Installs Docker Engine + Docker Compose v2 (official get.docker.com),
# and/or configures the current user to run docker without sudo.

set -euo pipefail

############################################
# Helpers
############################################
log()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m  %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]

Options:
  --install     Install Docker Engine + Compose v2 only (do not modify groups).
  --no-sudo     Configure the current user to run docker without sudo
                (adds user to the docker group). Assumes Docker is installed.
  --all         Install Docker AND configure passwordless usage. (default)
  -h, --help    Show this help.

Run with no arguments for an interactive prompt.
EOF
}

############################################
# Preflight checks
############################################
[ "$(uname -s)" = "Linux" ] || die "This script only supports Linux."
need_cmd curl || die "curl is required but not installed."

OS="$(uname -s)"
ARCH_RAW="$(uname -m)"
DISTRO="unknown"; VERSION_ID=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO="${ID:-unknown}"
  VERSION_ID="${VERSION_ID:-}"
fi

log "OS=$OS  Distro=$DISTRO ($VERSION_ID)  Arch=$ARCH_RAW"

############################################
# Install Docker Engine via official script
############################################
install_docker() {
  if need_cmd docker; then
    log "Docker already installed: $(docker --version)"
    return 0
  fi

  log "Downloading and running the official Docker install script from get.docker.com"
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sudo sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
}

############################################
# Add current user to the docker group
############################################
add_user_to_docker_group() {
  if ! need_cmd docker; then
    die "Docker is not installed. Run with --install or --all first."
  fi

  if ! getent group docker >/dev/null 2>&1; then
    log "Creating docker group"
    sudo groupadd docker
  fi

  local user; user="$(id -un)"
  if id -nG "$user" | tr ' ' '\n' | grep -qx 'docker'; then
    log "User '$user' is already in the docker group."
    return 0
  fi

  log "Adding '$user' to the docker group"
  sudo usermod -aG docker "$user"
  warn "Group membership takes effect in a new shell session."
  warn "Run: newgrp docker  (or log out and back in)"
}

############################################
# Enable and start Docker service
############################################
enable_docker_service() {
  if need_cmd systemctl; then
    log "Enabling and starting Docker service"
    sudo systemctl enable docker
    sudo systemctl start docker
  else
    warn "systemd not found. Start Docker manually: sudo service docker start"
  fi
}

############################################
# Verify
############################################
verify() {
  log "Verifying installation"
  docker --version       || warn "docker not found in PATH."
  docker compose version || warn "docker compose plugin not found."
  log "Testing with hello-world (using sudo since group change needs a new shell):"
  sudo docker run --rm hello-world || warn "hello-world test failed."
}

############################################
# Mode selection
############################################
prompt_mode() {
  echo
  echo "What would you like to do?"
  echo "  1) Install Docker Engine + Compose v2 (default)"
  echo "  2) Configure current user to run docker without sudo"
  echo "  3) Both — install AND configure passwordless usage"
  echo
  read -r -p "Enter choice [1-3] (default: 3): " choice
  case "${choice:-3}" in
    1) MODE="install" ;;
    2) MODE="no-sudo" ;;
    3) MODE="all" ;;
    *) die "Invalid choice: $choice" ;;
  esac
}

############################################
# Main
############################################
MODE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --install) MODE="install"; shift ;;
    --no-sudo) MODE="no-sudo"; shift ;;
    --all)     MODE="all"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [ -z "$MODE" ]; then
  if [ -t 0 ]; then
    prompt_mode
  else
    log "No TTY detected; defaulting to --all"
    MODE="all"
  fi
fi

log "Mode: $MODE"

case "$MODE" in
  install)
    install_docker
    enable_docker_service
    verify
    cat <<'EOF'

Docker is installed and running. To run docker without sudo later, re-run
this script with --no-sudo (or pass --all next time).
EOF
    ;;
  no-sudo)
    add_user_to_docker_group
    cat <<'EOF'

Done. To activate the new group membership, start a new shell session or run:
  newgrp docker

Then verify:
  docker run --rm hello-world
EOF
    ;;
  all)
    install_docker
    add_user_to_docker_group
    enable_docker_service
    verify
    cat <<'EOF'

Done. Docker is installed and running.

To use docker without sudo, start a new shell session or run:
  newgrp docker

Then verify:
  docker run --rm hello-world
  docker compose version
EOF
    ;;
esac
