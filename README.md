# server-tool

A collection of server setup and automation scripts.

---

## Scripts

### `install_docker_rootless.sh`

Installs **Docker (rootless mode)** and **Docker Compose v2** without requiring root for the Docker daemon itself. Only prerequisite package installation needs a one-time `sudo`.

#### What it does

1. Detects your OS, distro, and architecture automatically
2. Installs system prerequisites via the native package manager
3. Configures `subuid`/`subgid` for your user (required for rootless namespacing)
4. Runs the official Docker rootless installer (`get.docker.com/rootless`)
5. Appends `PATH` and `DOCKER_HOST` to `~/.bashrc` (idempotent — safe to re-run)
6. Enables and starts the Docker systemd user service (if systemd is available)
7. Downloads and installs the latest Docker Compose v2 CLI plugin to `~/.docker/cli-plugins/`

#### Supported distros

| Family | Package manager |
|---|---|
| Debian / Ubuntu | `apt` |
| Fedora | `dnf` |
| RHEL / CentOS / Rocky / AlmaLinux | `dnf` or `yum` |
| Arch / Manjaro | `pacman` |
| openSUSE / SUSE | `zypper` |
| Alpine | `apk` |

#### Supported architectures

`x86_64` / `aarch64` / `armv7`

#### Requirements

- Linux only
- Regular user account (not root)
- Internet access
- `sudo` available for prerequisite installation

#### Usage

```bash
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker_rootless.sh | sh
```

Or clone and run locally:

```bash
git clone https://github.com/fabinhere/server-tool.git
cd server-tool
chmod +x install_docker_rootless.sh
./install_docker_rootless.sh
```

After the script completes, open a new shell (or `source ~/.bashrc`) to pick up the environment variables, then verify:

```bash
docker info
docker compose version
docker run --rm hello-world
```

#### Environment variables set

```bash
export PATH="$HOME/bin:$PATH"
export DOCKER_HOST=unix:///run/user/<uid>/docker.sock
```

#### Notes

- Re-running the script is safe — the `~/.bashrc` block is only written once.
- If systemd user sessions are not available (e.g. minimal containers), start the daemon manually:
  ```bash
  dockerd-rootless.sh &
  ```
- `loginctl enable-linger` is called automatically so the Docker daemon persists across logouts.
