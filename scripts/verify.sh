#!/usr/bin/env bash
set -uo pipefail

# Verify origins locally, bypassing Cloudflare. Requires a valid certificate.
hosts=("$@")
if [ "${#hosts[@]}" -eq 0 ]; then
    hosts=(
        quitw.org
        www.quitw.org
        static.quitw.org
        blog.quitw.org
        blog-updater.quitw.org
        static-updater.quitw.org
        tools.quitw.org
        cyberchef.quitw.org
        learnx.quitw.org
        piano.quitw.org
        shell.quitw.org
        qui.quitw.org
        pbh.quitw.org
        whoami.quitw.org
        qbt504.quitw.org
        files504.quitw.org
    )
fi

fail=0
for host in "${hosts[@]}"; do
    path="/"
    method="GET"
    case "$host" in
        blog-updater.quitw.org) path="/run/blog-pull"; method="POST" ;;
        static-updater.quitw.org) path="/run/proxy-sync"; method="POST" ;;
    esac
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 25 \
        -X "$method" \
        --resolve "${host}:443:127.0.0.1" "https://${host}${path}" || echo "ERR")"
    case "$code" in
        200|204|301|302|401|403)
            printf 'OK    %-28s %s\n' "$host" "$code" ;;
        *)
            printf 'FAIL  %-28s %s\n' "$host" "$code"
            fail=1
            ;;
    esac
done

exit "$fail"
