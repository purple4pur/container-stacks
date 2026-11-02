#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"

mkdir -p "$unit_dir"

user_unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$user_unit_dir"

shopt -s nullglob
for src in "$repo"/quadlet/*.container "$repo"/quadlet/*.network; do
    ln -sfn "$src" "$unit_dir/$(basename "$src")"
done
for src in "$repo"/systemd/*.service "$repo"/systemd/*.timer; do
    ln -sfn "$src" "$user_unit_dir/$(basename "$src")"
done

systemctl --user daemon-reload
echo "linked units into $unit_dir and $user_unit_dir"
