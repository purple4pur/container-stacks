# Rootless Podman setup

Use this page to prepare a Linux host for the stack. Run every command as the
target user. A command with `sudo` needs root.

The stack runs rootless Podman 5 with Quadlet units. It needs a user session,
cgroup v2, a subordinate ID range, and permission to bind port 443. Do these
steps one time for each new host.

The units use `%h`, so any non-root account works.

This page targets Debian. On an SELinux host, the bind mounts also need a
relabel, which the units do not set.

## Precheck the host

If `podman` is missing, run [Install the packages](#install-the-packages)
first, then return here. Compare each output with the expected value.

| Check | Command | Expected |
|---|---|---|
| Not root | `id -u` | A number other than `0` |
| Podman | `podman --version` | `5.x` |
| Rootless mode | `podman info --format '{{.Host.Security.Rootless}}'` | `true` |
| cgroup v2 | `cat /sys/fs/cgroup/cgroup.controllers` | A controller list, such as `cpuset cpu io memory pids` |
| Storage driver | `podman info --format '{{.Store.GraphDriverName}}'` | `overlay` |
| User namespaces | `cat /proc/sys/user/max_user_namespaces` | A number above `0` |
| Subordinate IDs | `grep "^$USER:" /etc/subuid /etc/subgid` | A line for your user in each file |
| Lingering | `loginctl show-user "$USER" -p Linger` | `Linger=yes` |
| Session directory | `stat -c '%a' /run/user/$(id -u)` | `700` |
| Low port | `cat /proc/sys/net/ipv4/ip_unprivileged_port_start` | `443` or less |
| Clock | `timedatectl show -p NTPSynchronized --value` | `yes` |

`overlay` is the fast storage driver. `vfs` also works, but it copies every
layer and uses much more disk. Every other mismatch stops a unit from starting.

## Install the packages

```bash
sudo apt install podman uidmap passt slirp4netns fuse-overlayfs crun netavark aardvark-dns
```

The `uidmap` package provides `newuidmap` and `newgidmap`. The `passt` package
provides `pasta`. Podman uses `pasta` or `slirp4netns` for rootless networking.

Gate: `podman info` exits with status 0 and reports a storage driver.

## Add subordinate IDs

Rootless Podman maps container users onto a range of host IDs. The range comes
from `/etc/subuid` and `/etc/subgid`.

1. Run `grep "^$USER:" /etc/subuid /etc/subgid`.
2. If both files show your user, skip the next command.
3. Run `sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"`.
4. Run the check from step 1 again.

Gate: both files show your user with a range of at least 65536 IDs. Use a free
range if another user already owns `100000-165535`.

Test the mapping with `podman run --rm docker.io/library/alpine echo ok`. Gate:
the command prints `ok`. It pulls an image, so the host needs outbound network
access.

## Keep the units after logout

```bash
loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger
```

Gate: the output reads `Linger=yes`. systemd then starts the user units at boot
without a login.

## Allow port 443

Traefik publishes port 443. In rootless mode a helper process forwards the port
without root. The kernel refuses ports below `ip_unprivileged_port_start`
unless the host allows them.

```bash
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee /etc/sysctl.d/99-rootless-podman-ports.conf
sudo sysctl --system
cat /proc/sys/net/ipv4/ip_unprivileged_port_start
```

Gate: the output reads `80` or less. The stack needs at least `443`.

## Clone the repository

The units read `%h/container_stacks`. `%h` is the home directory. A clone in
another directory breaks every bind mount.

```bash
git clone https://github.com/purple4pur/container-stacks.git ~/container_stacks
```

Gate: `test -f ~/container_stacks/quadlet/traefik.container` exits with status
0.

## Create the state directories

Podman does not create a missing bind source. Create every source before the
first start.

```bash
install -d -m 755 \
  ~/.local/share/container_stacks/{blog/data,homepage/logs,peerbanhelper/data,qbittorrent/config,qbittorrent/downloads,qbittorrent/downloads/temp,qui/config,qui/logs,rustdesk,static/html,static/html/dashboard,static-updater/data,traefik/letsencrypt}
install -d -m 700 ~/.local/share/container_stacks/filebrowser
```

The blog updater resets an existing checkout. It does not clone the blog
repository. Run:

```bash
git clone https://github.com/purple4pur/purple4pur.github.io.git \
  ~/.local/share/container_stacks/blog/data/myblog
```

Gate: `test -d ~/.local/share/container_stacks/blog/data/myblog/docs` exits
with status 0. Without this checkout, `blog-web` and `blog-updater` fail.

## Create the secrets

Follow [Secrets](SECRETS.md). Create every file before the first start.
Traefik mounts three secret files, and frps and filebrowser mount one each, so a
missing file stops those units.

After you set `STATIC_PROXY_DIR`, create its publish directory:

```bash
install -d -m 755 ~/.local/share/container_stacks/static/html/<proxy-dir>
```

Gate: `stat -c '%a %n' ~/.config/container_stacks/secrets/*` reports mode `600`
for every file.

> [!WARNING]
> Do not start the units before the secret files exist. Traefik then fails with
> a missing mount, and the certificate request cannot start.

## Install and start the units

```bash
cd ~/container_stacks
scripts/install.sh
systemctl --user start traefik.service
```

No `enable` step is needed for the containers. The `[Install]` section adds each
unit to `default.target`, and lingering starts that target at boot.

Start the rest of the stack:

```bash
systemctl --user start homepage static blog-web blog-updater static-updater \
  it-tools cyberchef learnx piano-practice sshwifty qbittorrent qui \
  peerbanhelper filebrowser whoami frps rustdesk-hbbs rustdesk-hbbr
```

Gate: `systemctl --user is-active traefik.service` prints `active`.

Enable the image update timer:

```bash
systemctl --user enable --now image-update.timer
systemctl --user list-timers image-update.timer
```

Gate: the timer lists its next run at 05:00 Asia/Shanghai.

## Open the firewall

The host firewall and the cloud security group must allow inbound traffic on:

- TCP 443 for Traefik.
- TCP 21115 through 21119 and UDP 21116 for RustDesk.
- The frp client and SSH ports in `~/.config/containers/systemd/frps.container.d/10-ports.conf`.
- TCP and UDP for the qBittorrent torrent port. The listen port is
  `QBT_TORRENTING_PORT` in `quadlet/qbittorrent.container`; the host mapping is
  in `~/.config/containers/systemd/qbittorrent.container.d/10-ports.conf`.

Also point the `quitw.org` DNS records at the host. Allow outbound HTTPS and DNS
so Traefik can solve the Cloudflare DNS-01 challenge.

Gate: `ss -lntu` shows the listeners after the units start.

Do not open the container ports that only Traefik uses or the qBittorrent WebUI
port. Those ports stay on the container networks.

## Verify the result

```bash
podman info --format '{{.Host.Security.Rootless}} {{.Store.GraphDriverName}}'
podman ps --format '{{.Names}} {{.Status}}'
systemctl --user --failed
scripts/verify.sh
```

Gate: `podman info` prints `true overlay`, every container is `Up`, no unit is
listed as failed, and `scripts/verify.sh` exits with status 0. The script needs
a valid certificate, so run it after the first certificate issue.

## Troubleshoot a failure

- `cannot clone: Operation not permitted` on Ubuntu: AppArmor blocks user
  namespaces. Install the distribution's Podman AppArmor profile, or set
  `kernel.apparmor_restrict_unprivileged_userns=0` in `/etc/sysctl.d/`.
- `rootlessport cannot expose privileged port 443`: the low-port setting is not
  active. Return to [Allow port 443](#allow-port-443).
- `statfs ...: no such file or directory`: a bind source is missing. Return to
  [Create the state directories](#create-the-state-directories).
- A unit stays inactive: run `journalctl --user -u <unit> -n 50`, then
  `podman logs <container>`.
