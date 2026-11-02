# Operations

Use these procedures to install the stack, run it, and maintain it. Run every
command as the `purple4pur` user. The units use rootless Podman.

## Install the units

1. Run `scripts/install.sh`.
2. Check that the units exist with `systemctl --user list-units '*.service'`.

`scripts/install.sh` links every file in `quadlet/` into
`~/.config/containers/systemd/`. It links `systemd/*.timer` into
`~/.config/systemd/user/`. The script also runs `systemctl --user daemon-reload`.

## Start, stop, or inspect a unit

1. Start a unit with `systemctl --user start <unit>`.
2. Check its state with `systemctl --user status <unit>`.
3. Stop it with `systemctl --user stop <unit>`.

Use `podman ps` to list the active containers. Use `journalctl --user -u <unit>
-f` to follow the service log. Use `podman logs -f <container>` to follow the
container output.

## Change a unit

1. Edit the Quadlet file in `quadlet/`.
2. Run `systemctl --user daemon-reload`.
3. Run `systemctl --user restart <unit>`.

## Update container images

1. Check the timer with `systemctl --user list-timers image-update.timer`.
2. Preview the next update with `podman auto-update --dry-run`.

The timer runs `podman-auto-update.service` daily at 05:00 Asia/Shanghai. A
pinned tag tracks digest changes on that tag only. A new version still needs a
manual tag change.

## Create the secret files

Read [Secrets](SECRETS.md) before you start the stack for the first time.

## Trigger the static updater

The static updater listens on `POST https://static-updater.quitw.org/run/proxy-sync`.
The proxy config workflow sends the bearer token from `static-updater-runlet.env`
in the `Authorization` header.

1. Run `. ~/.config/container_stacks/secrets/static-updater-runlet.env`.
2. Run `curl -fsS -X POST -H "Authorization: Bearer $RUNLET_TOKEN" https://static-updater.quitw.org/run/proxy-sync`.
3. Check for the `synced <commit>` line in the response.

Runlet pulls `~/.local/share/container_stacks/static-updater/data/repo` and
resets it to `origin/master`. It publishes `out/*` to
`~/.local/share/container_stacks/static/html/<proxy-dir>` and `out/index.html` to
`~/.local/share/container_stacks/static/html/dashboard`. It then purges both
Cloudflare prefixes. Traefik exposes only that path and limits it to 3 requests
per minute.

## Trigger the blog updater

The blog updater listens on `POST https://blog-updater.quitw.org/run/blog-pull`.
The blog workflow sends the bearer token from `blog-runlet.env` in the
`Authorization` header.

1. Run `. ~/.config/container_stacks/secrets/blog-runlet.env`.
2. Run `curl -fsS -X POST -H "Authorization: Bearer $RUNLET_TOKEN" https://blog-updater.quitw.org/run/blog-pull`.
3. Check that the command exits with status 0.

Runlet fetches `~/.local/share/container_stacks/blog/data/myblog` and resets it
to `origin/main`. Traefik exposes only that path and limits it to 3 requests per
minute.

## Check repository hygiene

1. Run `scripts/check-hygiene.sh`.
2. Run `pre-commit install` to run the same check and Gitleaks before each
   commit.
