#!/bin/sh
# Runs inside an Alpine container on the frontend network. Resolves the frps
# container IP on Tokyo, then forwards the tunneled downloader ports. The IP is
# checked again while connected because frps gets a new address when it
# restarts. The container is named frp_server so PeerBanHelper keeps its
# existing endpoint.
set -eu

apk add --no-cache openssh-client >/dev/null

resolve_ip() {
    ssh -o BatchMode=yes -o ControlMaster=no -o ControlPath=none \
        -o ConnectTimeout=10 tokyo \
        "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frp_server"
}

ssh_pid=
cleanup() {
    if [ -n "$ssh_pid" ]; then
        kill "$ssh_pid" 2>/dev/null || true
    fi
    exit 0
}
trap cleanup TERM INT

current_ip=
while :; do
    ip="$(resolve_ip || true)"

    if [ -z "$ip" ]; then
        echo "cannot resolve frps container ip on tokyo" >&2
        sleep 10
        continue
    fi

    if [ -n "$ssh_pid" ]; then
        if kill -0 "$ssh_pid" 2>/dev/null; then
            if [ "$ip" = "$current_ip" ]; then
                sleep 60
                continue
            fi
            echo "frps ip changed: $current_ip -> $ip" >&2
            kill "$ssh_pid" 2>/dev/null || true
        fi
        wait "$ssh_pid" 2>/dev/null || true
    fi

    current_ip="$ip"
    ssh -N \
        -o BatchMode=yes \
        -o ControlMaster=no \
        -o ControlPath=none \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -L "0.0.0.0:18080:${ip}:18080" \
        -L "0.0.0.0:18081:${ip}:18081" \
        tokyo &
    ssh_pid=$!
    sleep 60
done
