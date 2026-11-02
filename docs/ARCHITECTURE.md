# Architecture

## Services

| Unit | Role | Persistent state |
|---|---|---|
| `traefik` | TLS termination and host routing | certificates |
| `homepage` | Dashboard | logs |
| `static` | Static site nginx | published files |
| `blog-web` | Blog content nginx | blog checkout |
| `blog-updater` | Runlet blog pull trigger | blog checkout |
| `static-updater` | Runlet proxy config sync trigger | proxy checkout, published files |
| `it-tools`, `cyberchef`, `learnx`, `piano-practice`, `sshwifty`, `qui`, `peerbanhelper`, `whoami` | Leaf services | per service |
| `frp-tunnel` | SSH tunnel to remote downloader ports | none |

## Networks and routing

All public containers join the `frontend` bridge network. Traefik publishes
port 443 and reads routes from `traefik/config/dynamic.yaml` through the file
provider. No container runtime socket is mounted into Traefik.

TLS certificates use the Cloudflare DNS-01 challenge. ACME state is kept in
the runtime state directory, never in the repository.

## Persistent state

Declarative configuration is tracked in the repository. Everything mutable is
mounted from outside the worktree:

```text
~/.local/share/container_stacks/<service>/
```

That includes databases, logs, cloned repositories, published static files,
and ACME state. `scripts/check-hygiene.sh` rejects any tracked path that looks
like one of those directories.

## Secrets

Bearer tokens, API tokens, and the GitHub PAT live in
`~/.config/container_stacks/secrets/` with mode 600. Units reference them
through `EnvironmentFile=` or a bind-mounted `/run/secrets/` file. The
repository only contains `.env.example` templates with placeholders.

## Update flow

- Container images update through `podman-auto-update` on a daily timer.
- The static site is push-triggered: the proxy config workflow calls a Runlet
  endpoint, which pulls the config repository and publishes a new snapshot.
- The blog mirror is push-triggered the same way through its own Runlet
  endpoint.
