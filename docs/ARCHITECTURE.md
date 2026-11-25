# Architecture

## Why this shape

The stack runs as a rootless Podman service for one user. Each container is a
systemd user unit, so boot startup, restart, and logs use systemd. Podman needs
no root daemon and no container runtime socket.

The repository tracks only declarative configuration. A clone of the repository
is safe to publish because live data and credentials live outside it. This
separation is the main design rule, and CI enforces it.

Each updater runs after a push to its source repository. The proxy config
repository and the blog repository call a Runlet endpoint. The stack does not
poll the remote repositories.

## Service model

Each container has one Quadlet file in `quadlet/`. systemd starts the units at
boot through user lingering. All public containers join the `frontend` bridge
network. `qbittorrent` joins `torrent.network` with `qui` and `peerbanhelper`;
that network is not routed by Traefik.

| Unit | Role | Persistent state |
|---|---|---|
| `traefik` | TLS termination and host routing | Certificates |
| `homepage` | Dashboard | Logs |
| `static` | Static file server | Published files |
| `blog-web` | Blog content server | Blog checkout |
| `blog-updater` | Blog pull trigger | Blog checkout |
| `static-updater` | Proxy config sync trigger | Proxy checkout and published files |
| `it-tools` | Developer tools | None |
| `cyberchef` | Data transformation | None |
| `learnx` | Code documentation | None |
| `piano-practice` | Staff reading practice | None |
| `sshwifty` | Web SSH client | None |
| `qbittorrent` | Torrent client with an internal WebUI | Configuration and downloads |
| `qui` | Torrent web UI | Configuration, logs, and database |
| `peerbanhelper` | Peer ban manager | Service data |
| `filebrowser` | Download browser and WebDAV | Configuration, database, and cache |
| `whoami` | Request echo test | None |
| `frps` | frp server for the local downloader tunnels | None |
| `rustdesk-hbbs` | RustDesk ID server | Server key and peer database |
| `rustdesk-hbbr` | RustDesk relay server | Server key and peer database |

## Network and routing

Traefik publishes port 443. It reads routes from
`traefik/config/dynamic.yaml` through the file provider. No container runtime
socket is mounted into Traefik.

The qBittorrent WebUI is not published and has no Traefik route. `qui` and
`peerbanhelper` reach it at `http://qbittorrent:8080` over `torrent.network`.
The torrent port is the only public qBittorrent port; its host mapping lives in
a local drop-in outside the worktree. Both bridge networks set
`isolate=true`, so only containers attached to both networks can cross between
them. `qui` and `peerbanhelper` are the only such containers.

`filebrowser` mounts the qBittorrent downloads read-write and serves WebDAV at
`https://files.quitw.org/dav/downloads/`. The public name is a DNS-only record at
Cloudflare, so uploads are not capped by the proxied request body limit.

TLS certificates use the Cloudflare DNS-01 challenge. Traefik stores ACME state
in the runtime state directory, not in the repository.

## State and secret boundaries

The repository tracks declarative configuration. It does not track mutable
state. Units mount all mutable data from outside the worktree:

```text
~/.local/share/container_stacks/<service>/
```

Databases, logs, cloned repositories, published files, and ACME state live
there. The qBittorrent configuration and downloads live under
`~/.local/share/container_stacks/qbittorrent/`; the WebUI password is stored
there as a hash. The FileBrowser database and cache live under
`~/.local/share/container_stacks/filebrowser/`. `scripts/check-hygiene.sh`
rejects tracked paths that look like state directories.

Bearer tokens, API tokens, and the GitHub PAT live in
`~/.config/container_stacks/secrets/` with mode 600. Units read them through
`EnvironmentFile=` or through a bind-mounted `/run/secrets/` file. The
repository tracks only placeholder templates. The frp port list and its
Traefik routes live there too, in `frps.toml` and `traefik-frp.yaml`.

## Update flow

`podman-auto-update` runs on a daily timer and updates container images. A unit
with `AutoUpdate=registry` restarts when the digest of its tag changes.

A proxy config workflow triggers the static site sync. It calls a Runlet
endpoint. Runlet pulls the config repository and publishes a new snapshot.

A blog workflow calls its Runlet endpoint in the same way. Runlet resets the
local blog checkout to `origin/main`.
