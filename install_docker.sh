#!/usr/bin/env bash
# install_docker.sh
# Installs Docker Engine + Docker Compose v2 following the official Docker documentation.
# Uses get.docker.com convenience script, adds current user to the docker group,
# and enables the Docker systemd service.
# Requires sudo for installation.

set -euo pipefail

############################################
# Helpers
############################################
log()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m  %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m  %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

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
  local user; user="$(id -un)"
  if groups "$user" | grep -q '\bdocker\b'; then
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
  docker --version   || warn "docker not found in PATH."
  docker compose version || warn "docker compose plugin not found."
  log "Testing with hello-world (requires group re-login, using sudo for now):"
  sudo docker run --rm hello-world
}

############################################
# Main
############################################
main() {
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
}

main "$@"
