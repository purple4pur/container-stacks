# container-stacks

Rootless Podman + Quadlet configuration for my self-hosted services.

This is v2 of the repository formerly named `docker_compose`. The old Docker
Compose tree is preserved on the [`v1-docker`](https://github.com/purple4pur/container-stacks/tree/v1-docker)
branch and is no longer maintained.

## Layout

```text
quadlet/        one systemd unit per container; source of truth
traefik/        static config and dynamic routes
homepage/       dashboard config
blog/           Runlet config and blog pull command
static-updater/ Runlet config and proxy sync command
sshwifty/       web SSH config
scripts/        install, verify, and tunnel helpers
systemd/        image update timer
docs/           architecture notes
```

Runtime state and secrets live outside this repository:

```text
~/.config/container_stacks/secrets/   # env files, mode 600
~/.local/share/container_stacks/      # volumes, logs, databases
```

The units reference those paths directly, so the repository can be cloned
anywhere and never contains live data or credentials.

## Daily commands

Quadlet units are symlinked into the user unit directory by `scripts/install.sh`.

```sh
scripts/install.sh                 # link units and reload systemd
systemctl --user start traefik     # start one unit
systemctl --user status traefik    # check it
podman ps                          # running containers
podman logs -f homepage            # follow logs
journalctl --user -u homepage -f   # service logs
```

Edit a unit in `quadlet/`, then run:

```sh
systemctl --user daemon-reload
systemctl --user restart <unit>
```

Units start at boot because user lingering is enabled.

## Image updates

`image-update.timer` runs `podman-auto-update.service` daily at 05:00
Asia/Shanghai. Every unit is marked `AutoUpdate=registry`, so it pulls its
image and restarts when the remote tag digest changes. Pinned tags track digest
changes on that tag only; a new version still needs a manual tag bump.

```sh
systemctl --user list-timers image-update.timer
podman auto-update --dry-run       # show what the next run would update
```

## Networking

All public containers join the `frontend` network. Traefik publishes 443 and
routes by hostname using the file provider in `traefik/config/dynamic.yaml`.
No Docker or Podman socket is mounted into Traefik.

## Secrets

Secrets are environment files under `~/.config/container_stacks/secrets/`
(mode 600). They are created from the tracked examples and never committed.

| File | Purpose | Example |
|---|---|---|
| `traefik.env` | Cloudflare DNS-01 token | `traefik/.env.example` |
| `cloudflare.env` | Cache-purge token and zone ID | `scripts/cloudflare.env.example` |
| `blog-runlet.env` | Blog updater bearer token | `blog/runlet.env.example` |
| `static-updater-runlet.env` | Static updater bearer token | `static-updater/runlet.env.example` |
| `static-updater-git.env` | Read-only GitHub PAT | `static-updater/git.env.example` |

```sh
install -d -m 700 ~/.config/container_stacks/secrets
install -m 600 /dev/null ~/.config/container_stacks/secrets/traefik.env
```

The DNS-01 token needs DNS edit permission for the zone. The GitHub token is a
fine-grained PAT with contents read-only on the proxy config repository.

## Static updater

`static-updater.quitw.org` exposes one runlet command: `POST /run/proxy-sync`.
The `proxy-config-updater` workflow calls it after it pushes a new `out/`
snapshot. The command pulls `~/.local/share/container_stacks/static-updater/data/repo`,
resets it to `origin/master`, atomically publishes `out/*` to
`~/.local/share/container_stacks/static/html/<proxy-dir>` and `out/index.html` to
`~/.local/share/container_stacks/static/html/dashboard`, then purges both
Cloudflare prefixes. Traefik exposes only that path and limits it to 3 requests
per minute.

## Blog updater

`blog-updater.quitw.org` exposes one runlet command: `POST /run/blog-pull`.
It fetches `~/.local/share/container_stacks/blog/data/myblog` and resets it to
`origin/main`. Traefik exposes only that path and limits it to 3 requests per
minute.

## Repository hygiene

`scripts/check-hygiene.sh` enforces the three repository rules:

1. No v1 files: the old Compose tree lives only on `v1-docker`.
2. No runtime data or generated output: volumes, logs, databases, and published
   files stay under `~/.local/share/container_stacks/`.
3. No credentials: only `.env.example` files may be tracked.

CI runs that check on every push and pull request, plus a gitleaks history
scan. The pre-commit config runs both hooks locally.
