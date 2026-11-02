#!/usr/bin/env bash
set -euo pipefail

# Reject tracked files that do not belong in the public configuration repo.
# Keep this list in sync with the layout documented in README.md.

cd "$(git rev-parse --show-toplevel)"

allowed='^(README\.md|\.gitignore|\.gitattributes|\.pre-commit-config\.yaml)$'
allowed+='|^\.github/workflows/[^/]+\.ya?ml$'
allowed+='|^(quadlet|systemd|scripts|docs)/[^/]+$'
allowed+='|^(blog|homepage|static-updater|sshwifty|traefik)/config/.+$'
allowed+='|^(blog|static-updater|traefik)/[^/]*\.env\.example$'

forbidden='(^|/)(legacy|data|logs|html|letsencrypt|backups?)/'
forbidden+='|(^|/)[^/]*\.env$'
forbidden+='|(^|/)acme[^/]*\.json$'
forbidden+='|\.(db|db-wal|db-shm|key|pem|p12|pfx|log|gz|zip|psd)$'

tracked="$(git ls-files)"
status=0

unexpected="$(printf '%s\n' "$tracked" | grep -vE "$allowed" || true)"
if [ -n "$unexpected" ]; then
    echo "error: tracked paths outside the allowlist:" >&2
    printf '%s\n' "$unexpected" >&2
    status=1
fi

blocked="$(printf '%s\n' "$tracked" | grep -E "$forbidden" || true)"
if [ -n "$blocked" ]; then
    echo "error: tracked runtime, output, or secret paths:" >&2
    printf '%s\n' "$blocked" >&2
    status=1
fi

exit "$status"
