# MTProxy Docker

Lightweight Docker image for [Telegram MTProxy](https://github.com/TelegramMessenger/MTProxy) based on Alpine Linux.

## Features

- Alpine multi-stage build (~15 MB runtime image)
- Auto-fetches Telegram proxy configs on startup
- Daily config refresh via cron (04:00 UTC)
- Automatic secret generation with persistence
- NAT detection for cloud/VPS environments
- Runs as non-root user

## Quick Start

```bash
docker build -t mtproxy .
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 443:443 \
  -v mtproxy-data:/data \
  mtproxy
```

Check logs for your connection link:

```bash
docker logs mtproxy
```

Output will contain a `tg://proxy?server=...&port=...&secret=...` link ready to use.

Modern Telegram clients require the `dd` prefix for random padding to packets or `ee` prefix for fake-TLS mode. Your tg:// link should use:
`tg://proxy?server=YOUR_IP&port=443&secret=ddSECRET`

The `ee` prefix tells the client to use fake-TLS transport (makes traffic look like HTTPS). Without it, many networks and ISPs block the plain MTProto protocol.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SECRET` | auto-generated | Proxy secret (32 hex chars). Comma-separated for multiple secrets |
| `TAG` | — | Advertisement tag from [@MTProxybot](https://t.me/MTProxybot) |
| `WORKERS` | `0` | Number of worker processes |
| `PORT` | `443` | Client-facing port |
| `STATS_PORT` | `2398` | Statistics HTTP port |
| `EXTERNAL_IP` | auto-detected | Override external IP for NAT |
| `EPOLL_TIMEOUT` | `50` | Event loop poll interval in ms (1-1000) |
| `DOMAIN` | — | Domain for TLS-transport (comma-separated for multiple). Disables other transports |
| `DC_LIMIT` | — | Max IPs per DC in proxy-multi.conf (reduces idle connections, all DCs kept) |

## Examples

With explicit secret and tag:

```bash
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 443:443 \
  -v mtproxy-data:/data \
  -e SECRET=00baadf00d15abad1deaa51sbaadcafe \
  -e TAG=your_tag_here \
  mtproxy
```

Custom port and workers:

```bash
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 8443:8443 \
  -v mtproxy-data:/data \
  -e PORT=8443 \
  -e WORKERS=4 \
  mtproxy
```

## TLS-Transport Mode

TLS-transport makes MTProxy traffic look like regular HTTPS to network observers. When enabled, all non-TLS transports are disabled. The domain must support TLS 1.3.

```bash
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 443:443 \
  -v mtproxy-data:/data \
  -e DOMAIN=www.google.com \
  mtproxy
```

Multiple domains:

```bash
-e DOMAIN=www.google.com,www.cloudflare.com
```

The client secret for TLS-transport uses the `ee` prefix format:
`ee` + `<secret>` + `<domain in hex>`

For example, with secret `00112233445566778899aabbccddeeff` and domain `www.google.com`:
`ee00112233445566778899aabbccddeeff7777772e676f6f676c652e636f6d`

The startup log prints the ready-to-use `tg://` link with the correct `ee`-prefixed secret.

> **Note:** Using multiple workers (`WORKERS`) with TLS-transport is not recommended for better replay protection. When `DOMAIN` is set, consider leaving `WORKERS` at the default.

## CPU Usage Tuning

The default `EPOLL_TIMEOUT=50` (50ms) keeps idle CPU near 0%. The upstream default is 1ms which causes 3-4% CPU usage even with zero connections. Lower values give lower latency, higher values save CPU:

- `1` — upstream default, lowest latency, ~3-4% idle CPU
- `50` — good balance (default in this image)
- `100` — minimal CPU, fine for personal use

```bash
-e EPOLL_TIMEOUT=100
```

MTProxy also keeps ~4 persistent connections per DC target per worker. With ~22 targets and 2 workers that's ~176 idle connections. Most come from DC 4 (10 IPs). Use `DC_LIMIT` to cap IPs per DC while keeping all DCs reachable:

```bash
-e DC_LIMIT=1
```

## High Load

For many simultaneous connections, raise the file descriptor limit:

```bash
docker run -d \
  --name mtproxy \
  --restart unless-stopped \
  -p 443:443 \
  --ulimit nofile=98304:98304 \
  -v mtproxy-data:/data \
  mtproxy
```

Without this flag the proxy automatically reduces `maxconn` to fit the default container limit (~1024). This is fine for personal use but not enough for a public proxy.

## Stats

```bash
curl http://localhost:2398/stats
```

## Persistent Data

The `/data` volume stores:

- `secret` — generated proxy secret (reused across restarts)
- `proxy-secret` — Telegram crypto secret (refreshed daily)
- `proxy-multi.conf` — Telegram datacenter config (refreshed daily)
