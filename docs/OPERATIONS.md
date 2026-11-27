# Operations

Use these procedures to install the stack, run it, and maintain it. Run every
command as the `purple4pur` user. The units use rootless Podman.

## Install the units

Read [Rootless Podman setup](ROOTLESS.md) first on a new host.

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

Floating minor tags, such as `traefik:v3.7`, only move while upstream maintains
that minor line. When a line goes end of life the tag silently freezes, so a
quiet `podman auto-update --dry-run` for months means it is time to compare
`quadlet/*.container` against upstream releases and bump the tag.

Traefik tracks the current minor (`v3.7`, latest `v3.7.17`). The 3.6 line
stopped at `v3.6.25` and receives no more security patches.

qBittorrent tracks `latest`. `qui` and `peerbanhelper` follow the qBittorrent
WebAPI, so check both after a qBittorrent minor or major update. Pin a previous
tag if either service rejects the new API.

## Check the frp server

1. Run `systemctl --user status frps`.
2. Run `podman logs --tail 50 frp_server`.
3. Check for the client login and the proxy start lines.

The server reads `~/.config/container_stacks/secrets/frps.toml`. That file holds
the client port and the allowed tunnel ports. The tunneled services are
reachable on the `frontend` network at `frp_server`.

## Check qBittorrent

1. Run `systemctl --user status qbittorrent`.
2. Run `podman logs --tail 50 qbittorrent` and check the WebUI line and the
   torrent port.
3. Run `podman port qbittorrent` and check the torrent TCP and UDP mappings.
4. Run `podman exec qbittorrent curl -fsS -o /dev/null
   http://localhost:8080/` and check that it exits with status 0.

The WebUI is not published and has no Traefik route. `qui` and `peerbanhelper`
reach it at `http://qbittorrent:8080` over `torrent.network`. Add the instance to
both services with the WebUI credentials. If you keep a local credentials
record, it is `~/.config/container_stacks/secrets/qbittorrent-webui.env`. This is
a dedicated instance; it does not replace `qbt504`.

The torrent port mapping stays outside the worktree. Create it once:

1. Run `install -d -m 700 ~/.config/containers/systemd/qbittorrent.container.d`.
2. Create `~/.config/containers/systemd/qbittorrent.container.d/10-ports.conf`:

   ```ini
   [Container]
   PublishPort=<torrent-port>:<torrent-port>/tcp
   PublishPort=<torrent-port>:<torrent-port>/udp
   ```

3. Run `chmod 600 ~/.config/containers/systemd/qbittorrent.container.d/10-ports.conf`.
4. Run `systemctl --user daemon-reload`.
5. Run `systemctl --user restart qbittorrent`.

`<torrent-port>` must match `QBT_TORRENTING_PORT` in
`quadlet/qbittorrent.container`; the tracked unit uses `16881`. Open the same
TCP and UDP port in the host firewall and the cloud security group. Do not open
the WebUI port.

> [!NOTE]
> Rootless bridge networking has a known UDP source-port conflict: when the
> torrent UDP port is published, outbound UDP from that same source port can be
> dropped. qBittorrent then reports `firewalled` with `dht_nodes=0`, although
> inbound TCP still works. To restore DHT and uTP, move qBittorrent to pasta
> networking (Podman 6 with `rootless_port_forwarder="pasta"`, or a pod with
> `Network=pasta`) and stop publishing UDP on the bridge.

## Set the qBittorrent WebUI credentials

The first start prints a temporary `admin` password in `podman logs qbittorrent`.
The WebUI is only reachable from `torrent.network`, so use a temporary loopback
publish to configure it:

1. Add `PublishPort=127.0.0.1:8080:8080` to the local
   `qbittorrent.container.d/10-ports.conf`.
2. Run `systemctl --user daemon-reload` and `systemctl --user restart qbittorrent`.
3. Open an SSH tunnel from your workstation: `ssh -L 8080:127.0.0.1:8080 <host>`.
4. Open `http://127.0.0.1:8080`, sign in with the temporary password, and set a
   permanent password in the WebUI settings. Disable UPnP/NAT-PMP and keep the
   incoming port at `QBT_TORRENTING_PORT`.
5. Remove the `PublishPort=127.0.0.1:8080:8080` line, then run
   `systemctl --user daemon-reload` and `systemctl --user restart qbittorrent`.

Store the credentials outside the worktree, for example in
`~/.config/container_stacks/secrets/qbittorrent-webui.env` with mode 600. Do not
commit them.

## Check FileBrowser

1. Run `systemctl --user status filebrowser`.
2. Run `podman logs --tail 50 filebrowser`.
3. Open `https://files.quitw.org/`.

The admin password is `FILEBROWSER_ADMIN_PASSWORD` in `filebrowser.env`:

```bash
grep '^FILEBROWSER_ADMIN_PASSWORD=' ~/.config/container_stacks/secrets/filebrowser.env
```

Sign in as `admin`. The unit reapplies this value on every restart, so change it
in the secret file, not in the Web UI. The unit mounts
`~/.local/share/container_stacks/qbittorrent/downloads` read-write at
`/downloads`, so uploads land where qBittorrent can seed them. The database and
cache live under `~/.local/share/container_stacks/filebrowser/`.

The `files.quitw.org` record is **DNS only** (grey cloud). A proxied record caps
every upload at the Cloudflare request body limit, 100 MB on Free and Pro.

FileBrowser trusts forwarded scheme and host headers, but not client IPs. Login
rate limiting and the activity log therefore see the Traefik container address.
That is acceptable for a single-admin instance.

### Mount FileBrowser over WebDAV

1. In the Web UI, open **Settings → API Tokens** and create a token without
   customization. Copy the full value.
2. Use `https://files.quitw.org/dav/downloads/` as the server URL.
3. Use any username. The password is the API token.

WebDAV requires the `api` permission, which the admin user has by default.
Read-only clients need view and download; write clients also need create,
modify, and delete.

## Check RustDesk

1. Run `systemctl --user status rustdesk-hbbs rustdesk-hbbr`.
2. Run `podman logs --tail 50 hbbs`.
3. Connect a client to `sobad.quitw.org`.

The units share `~/.local/share/container_stacks/rustdesk`. Keep `id_ed25519`
there. A new key breaks the trust of every existing client.

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
`~/.local/share/container_stacks/static/html/<proxy-dir>` and `out/index.html`
to `~/.local/share/container_stacks/static/html/dashboard`. `<proxy-dir>` is
the `STATIC_PROXY_DIR` value from `static-updater-runlet.env`. Runlet then
purges both Cloudflare prefixes. Traefik exposes only that path and limits it
to 3 requests per minute.

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
