# server-tool

A collection of server setup and automation scripts.

---

## Scripts

### `install_docker.sh`

Installs **Docker Engine** and **Docker Compose v2** via the [official Docker convenience script](https://get.docker.com), and/or configures the current user to run `docker` without `sudo`.

#### Modes

| Flag | Behavior |
|---|---|
| `--install` | Install Docker Engine + Compose v2 only (do not modify groups). |
| `--no-sudo` | Add current user to the `docker` group (assumes Docker is already installed). |
| `--all` | Install Docker **and** configure passwordless usage. *(default)* |
| `-h`, `--help` | Show help. |

If no flag is passed, the script prompts you interactively to pick a mode — this works both when run locally and when piped through `curl ... | bash` (the prompt reads from `/dev/tty`). If no terminal is available at all (e.g. fully non-interactive automation), it defaults to `--all`.

#### Requirements

- Linux
- `sudo` access
- `curl`
- Internet access

#### Usage

Interactive (prompts for mode):

```bash
git clone https://github.com/fabinhere/server-tool.git
cd server-tool
chmod +x install_docker.sh
./install_docker.sh
```

One-liner (defaults to `--all`):

```bash
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker.sh | bash
```

Pick a specific mode:

```bash
# Install only
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker.sh | bash -s -- --install

# Configure passwordless docker on a host where Docker is already installed
curl -fsSL https://raw.githubusercontent.com/fabinhere/server-tool/main/install_docker.sh | bash -s -- --no-sudo
```

After the script completes, start a new shell session (or run `newgrp docker`) to use `docker` without `sudo`:

```bash
docker run --rm hello-world
docker compose version
```
