# server-tool

A collection of server setup and automation scripts.

---

## Scripts

### `install_docker.sh` — Recommended

Installs **Docker Engine** and **Docker Compose v2** using the [official Docker convenience script](https://get.docker.com). This is the standard documented approach: Docker daemon runs as root, your user is added to the `docker` group so you can run `docker` without `sudo`.

#### What it does

1. Runs the official `get.docker.com` installer
2. Adds your user to the `docker` group
3. Enables and starts the Docker systemd service
4. Verifies the installation with `hello-world`

#### Requirements

- Linux
- `sudo` access
- `curl`
- Internet access

#### Usage

```bash
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/fabinhere/server-tool.git
cd server-tool
chmod +x install_docker.sh
./install_docker.sh
```

After the script completes, start a new shell session (or run `newgrp docker`) to use `docker` without `sudo`:

```bash
docker run --rm hello-world
docker compose version
```

---

### `install_docker_rootless.sh` — Advanced

Installs Docker in **rootless mode** where the Docker daemon itself runs as your user — no root daemon at all. Useful for hardened environments where running a root-owned daemon is not acceptable.

> **Note:** Rootless mode requires kernel support for user namespaces and `nf_tables`. If your kernel/distro does not have these, use `install_docker.sh` instead.

#### What it does

1. Installs system prerequisites via the native package manager (`apt`, `dnf`, `yum`, `pacman`, `zypper`, `apk`)
2. Configures `subuid`/`subgid` for your user
3. Runs the official Docker rootless installer (`get.docker.com/rootless`)
4. Appends `PATH` and `DOCKER_HOST` to `~/.bashrc` (idempotent — safe to re-run)
5. Enables the Docker systemd user service
6. Installs the latest Docker Compose v2 CLI plugin to `~/.docker/cli-plugins/`

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

#### Usage

> **Do not prefix with `sudo`** — the script calls `sudo` internally where needed.
> **Do not use `| sh`** — use `| bash`. The shebang is ignored when piping, and `sh` (dash) does not support `pipefail`.

```bash
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker_rootless.sh | bash
```

After install, open a new shell or run `source ~/.bashrc`, then verify:

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
