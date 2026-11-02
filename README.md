# container-stacks

Rootless Podman and Quadlet configuration for a self-hosted service stack.

## What this repository is

This repository holds declarative configuration only. Podman reads one Quadlet
unit per container from `quadlet/`. Traefik reads routes from
`traefik/config/dynamic.yaml`. The dashboard and the other services read their
configuration from the tracked `config/` directories.

The repository never holds live data or credentials. Runtime state lives under
`~/.local/share/container_stacks/`. Secrets live under
`~/.config/container_stacks/secrets/` with mode 600.

## Branch model

`main` holds the current Podman and Quadlet stack. `v1-docker` holds the old
Docker Compose stack and receives no updates. Use the
[`v1-docker` branch](https://github.com/purple4pur/container-stacks/tree/v1-docker)
when you need the old files.

## Repository layout

| Path | Contents |
|---|---|
| `quadlet/` | One systemd unit per container |
| `traefik/` | Static configuration and dynamic routes |
| `homepage/` | Dashboard configuration |
| `blog/` | Runlet configuration for the blog pull |
| `static-updater/` | Runlet configuration for the proxy sync |
| `sshwifty/` | Web SSH configuration |
| `scripts/` | Install, verify, tunnel, and hygiene helpers |
| `systemd/` | Image update timer |
| `docs/` | Architecture, operations, and secret documents |

## Repository rules

The `main` branch follows three rules:

1. No v1 files. The old Compose tree stays on `v1-docker`.
2. No runtime data or generated output. Volumes, logs, databases, and published
   files stay outside the worktree.
3. No credentials. Only `.env.example` files may be tracked.

`scripts/check-hygiene.sh` checks these rules. CI runs the check on every push
and pull request. Gitleaks checks the history for secrets.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) explains the service model and the state
  and secret boundaries.
- [Operations](docs/OPERATIONS.md) gives the commands to install, run, and
  maintain the stack.
- [Secrets](docs/SECRETS.md) gives the steps to create the local environment
  files.
