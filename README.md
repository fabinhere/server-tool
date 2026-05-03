# server-tool

A collection of server setup and automation scripts.

---

## Scripts

### `install_docker.sh`

Installs **Docker Engine** and **Docker Compose v2** using the [official Docker convenience script](https://get.docker.com). Docker daemon runs as root, your user is added to the `docker` group so you can run `docker` without `sudo`.

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
