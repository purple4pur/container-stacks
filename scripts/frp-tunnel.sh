#!/bin/sh
# Runs inside an Alpine container on the frontend network. Resolves the frps
# container IP on Tokyo, then forwards the tunneled downloader ports. The
# container is named frp_server so PeerBanHelper keeps its existing endpoint.
set -eu

apk add --no-cache openssh-client >/dev/null

ip="$(ssh -o BatchMode=yes -o ControlMaster=no -o ControlPath=none \
    -o ConnectTimeout=10 tokyo \
    "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' frp_server")"

if [ -z "$ip" ]; then
    echo "cannot resolve frps container ip on tokyo" >&2
    exit 1
fi

exec ssh -N \
    -o BatchMode=yes \
    -o ControlMaster=no \
    -o ControlPath=none \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L "0.0.0.0:18080:${ip}:18080" \
    -L "0.0.0.0:18081:${ip}:18081" \
    tokyo
