#!/bin/sh
set -e

CONFIG_DIR="/data"
SECRET_FILE="$CONFIG_DIR/secret"

WORKERS="${WORKERS:-2}"
PORT="${PORT:-443}"
STATS_PORT="${STATS_PORT:-2398}"
export EPOLL_TIMEOUT="${EPOLL_TIMEOUT:-50}"

mkdir -p "$CONFIG_DIR"

# --- Fetch Telegram configuration ---
echo "Fetching proxy-secret..."
curl -sf https://core.telegram.org/getProxySecret -o "$CONFIG_DIR/proxy-secret"

echo "Fetching proxy-multi.conf..."
curl -sf https://core.telegram.org/getProxyConfig -o "$CONFIG_DIR/proxy-multi.conf"

/usr/local/bin/trim-config.sh "$CONFIG_DIR/proxy-multi.conf"

# --- Secret management ---
if [ -z "$SECRET" ]; then
    if [ -f "$SECRET_FILE" ]; then
        SECRET=$(cat "$SECRET_FILE")
        echo "Loaded existing secret from $SECRET_FILE"
    else
        SECRET=$(head -c 16 /dev/urandom | xxd -p)
        echo "$SECRET" > "$SECRET_FILE"
        echo "Generated new secret and saved to $SECRET_FILE"
    fi
fi

# --- IP detection for NAT ---
INTERNAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(curl -sf4 https://api.ipify.org || curl -sf4 https://ifconfig.me || true)
fi

NAT_ARGS=""
if [ -n "$INTERNAL_IP" ] && [ -n "$EXTERNAL_IP" ]; then
    NAT_ARGS="--nat-info ${INTERNAL_IP}:${EXTERNAL_IP}"
    echo "NAT: ${INTERNAL_IP} -> ${EXTERNAL_IP}"
elif [ -n "$INTERNAL_IP" ]; then
    echo "WARNING: Could not detect external IP. Set EXTERNAL_IP env variable."
fi

# --- Optional proxy tag ---
TAG_ARGS=""
if [ -n "$TAG" ]; then
    TAG_ARGS="-P $TAG"
fi

# --- Build -S flags for secrets (comma-separated support) ---
SECRET_ARGS=""
OLD_IFS="$IFS"
IFS=","
for s in $SECRET; do
    SECRET_ARGS="$SECRET_ARGS -S $s"
done
IFS="$OLD_IFS"

# --- Start cron for daily config updates ---
echo "0 4 * * * DC_LIMIT=$DC_LIMIT /usr/local/bin/update-config.sh" | crontab -
crond

echo "============================================"
echo "MTProxy is starting"
echo "Port: $PORT | Workers: $WORKERS | Stats: $STATS_PORT"
echo "Secret(s): $SECRET"
if [ -n "$EXTERNAL_IP" ]; then
    OLD_IFS="$IFS"
    IFS=","
    for s in $SECRET; do
        echo "  tg://proxy?server=${EXTERNAL_IP}&port=${PORT}&secret=${s}"
    done
    IFS="$OLD_IFS"
fi
echo "============================================"

# --- Launch proxy, -u drops privileges to mtproxy after binding ports ---
# shellcheck disable=SC2086
exec /usr/local/bin/mtproto-proxy \
    -u mtproxy \
    -p "$STATS_PORT" \
    -H "$PORT" \
    $SECRET_ARGS \
    --aes-pwd "$CONFIG_DIR/proxy-secret" \
    $NAT_ARGS \
    $TAG_ARGS \
    -M "$WORKERS" \
    --http-stats \
    "$CONFIG_DIR/proxy-multi.conf"
