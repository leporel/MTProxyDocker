#!/bin/sh
# Limits proxy-multi.conf to DC_LIMIT IPs per DC group.
# All DCs remain reachable; only excess IPs within a DC are removed.
# Usage: trim-config.sh <config-file-path>

if [ -n "$DC_LIMIT" ] && [ "$DC_LIMIT" -gt 0 ] 2>/dev/null; then
    awk -v limit="$DC_LIMIT" '
        /^proxy_for / { dc=$2; count[dc]++; if (count[dc] > limit) next }
        /^proxy [0-9]/ { count["_default"]++; if (count["_default"] > limit) next }
        { print }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    echo "Trimmed proxy-multi.conf to max $DC_LIMIT IP(s) per DC"
fi
