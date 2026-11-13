# Secrets

The stack reads secrets from files under
`~/.config/container_stacks/secrets/`. The directory has mode 700 and each file
has mode 600. The repository tracks no real secret values.

## Create the directory

1. Run `install -d -m 700 ~/.config/container_stacks/secrets`.
2. Run `ls -ld ~/.config/container_stacks/secrets` and check for mode `drwx------`.

## Create each file

For each file with an example, copy it, replace every placeholder, and set
mode 600.

| File | Example | Purpose |
|---|---|---|
| `traefik.env` | `traefik/.env.example` | Cloudflare DNS-01 token |
| `cloudflare.env` | `scripts/cloudflare.env.example` | Cache purge token and zone ID |
| `blog-runlet.env` | `blog/runlet.env.example` | Blog updater bearer token |
| `static-updater-runlet.env` | `static-updater/runlet.env.example` | Static updater bearer token and proxy directory name |
| `static-updater-git.env` | `static-updater/git.env.example` | Read-only GitHub PAT |
| `frps.toml` | none | frp server config: the client port and the allowed tunnel ports |

1. Run `cp <example> ~/.config/container_stacks/secrets/<file>`.
2. Edit the new file and replace every placeholder.
3. Run `chmod 600 ~/.config/container_stacks/secrets/<file>`.

## Create the frps config

The frp ports stay out of the repository. Create the server config at
`~/.config/container_stacks/secrets/frps.toml` before the first start:

```toml
bindPort = <frps-port>
kcpBindPort = <frps-port>

allowPorts = [
  { single = <ssh-port> },
  { single = <qbt-port> },
  { single = <files-port> },
]
```

Add one `single` entry for each forwarded port.

Publish the client and SSH ports through a Quadlet drop-in.

1. Run `install -d -m 700 ~/.config/containers/systemd/frps.container.d`.
2. Create `~/.config/containers/systemd/frps.container.d/10-ports.conf`.
3. Add these lines:

   ```ini
   [Container]
   PublishPort=<frps-port>:<frps-port>
   PublishPort=<ssh-port>:<ssh-port>
   ```

4. Run `chmod 600 ~/.config/containers/systemd/frps.container.d/10-ports.conf`.
5. Run `systemctl --user daemon-reload`.

The drop-in stays outside the worktree. `scripts/install.sh` does not touch it.

## Token permissions

The Cloudflare DNS-01 token needs DNS edit permission for the zone. The cache
purge token needs cache purge permission only. The GitHub token is a
fine-grained PAT with contents read-only on the proxy config repository.

Generate the two Runlet bearer tokens with `openssl rand -hex 32`.

`STATIC_PROXY_DIR` names the proxy snapshot directory under the static site.
Treat the value as a secret. Do not add it to a tracked file.

## Check the result

1. Run `stat -c '%a %n' ~/.config/container_stacks/secrets/*`.
2. Check that every file reports mode `600`.
3. Check that `git status --short` reports no new files.
