#!/bin/sh
# Git credential helper for the read-only proxy-config-updater PAT.
test "$1" = get || exit 0
printf 'username=%s\n' "${GITHUB_USER:-purple4pur}"
printf 'password=%s\n' "$GITHUB_TOKEN"
