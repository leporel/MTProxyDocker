#!/bin/sh
# Fetches fresh Telegram proxy configuration files daily via cron.
# If the proxy process is running, it gets killed so the entrypoint restarts it.

set -e

CONFIG_DIR="/data"

curl -sf https://core.telegram.org/getProxySecret -o "$CONFIG_DIR/proxy-secret.tmp" && \
    mv "$CONFIG_DIR/proxy-secret.tmp" "$CONFIG_DIR/proxy-secret"

curl -sf https://core.telegram.org/getProxyConfig -o "$CONFIG_DIR/proxy-multi.conf.tmp" && \
    mv "$CONFIG_DIR/proxy-multi.conf.tmp" "$CONFIG_DIR/proxy-multi.conf"

/usr/local/bin/trim-config.sh "$CONFIG_DIR/proxy-multi.conf"

# Signal the proxy to stop — the container entrypoint (PID 1) will handle restart
PID=$(pidof mtproto-proxy 2>/dev/null || true)
if [ -n "$PID" ]; then
    kill "$PID"
fi
