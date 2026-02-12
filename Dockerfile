# Stage 1: Build
FROM alpine:3.23 AS builder

RUN apk add --no-cache \
    build-base \
    linux-headers \
    openssl-dev \
    zlib-dev \
    git

COPY MTProxy/ /src/MTProxy/
COPY musl-compat.h /src/MTProxy/common/musl-compat.h
WORKDIR /src/MTProxy

# Patch for musl libc: inject compat header and fix connect() pointer casts
RUN sed -i '/#include <stdlib.h>/a #include "common/musl-compat.h"' jobs/jobs.h && \
    sed -i 's|#include <execinfo.h>|#include "common/musl-compat.h"|' common/server-functions.c && \
    sed -i 's/connect (sockets\[i\], &addr,/connect (sockets[i], (struct sockaddr *)\&addr,/g' \
        net/net-tcp-rpc-ext-server.c && \
    sed -i '/cannot raise open file limit/{n;s/exit (1);/struct rlimit rlim; getrlimit(RLIMIT_NOFILE, \&rlim); if (maxconn > (int)rlim.rlim_cur - gap) maxconn = (int)rlim.rlim_cur - gap; tcp_set_max_connections(maxconn);/}' engine/engine.c && \
    sed -i 's/mtproto_front_functions\.allowed_signals/{ const char *ep = getenv("EPOLL_TIMEOUT"); if (ep \&\& atoi(ep) > 0) mtproto_front_functions.epoll_timeout = atoi(ep); } mtproto_front_functions.allowed_signals/' mtproto/mtproto-proxy.c && \
    sed -i 's/engine_check_multithread_enabled () ? E->epoll_wait_timeout : 1/E->epoll_wait_timeout/' engine/engine.c

RUN make -j"$(nproc)"

# Stage 2: Runtime
FROM alpine:3.23

RUN apk add --no-cache \
    curl \
    ca-certificates \
    su-exec \
    xxd \
    iproute2 \
    libcrypto3 \
    zlib && \
    adduser -D -H -s /sbin/nologin mtproxy && \
    mkdir -p /data && chown mtproxy:mtproxy /data

COPY --from=builder /src/MTProxy/objs/bin/mtproto-proxy /usr/local/bin/mtproto-proxy
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY update-config.sh /usr/local/bin/update-config.sh
COPY trim-config.sh /usr/local/bin/trim-config.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/update-config.sh /usr/local/bin/trim-config.sh

VOLUME /data
EXPOSE 443 2398

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
