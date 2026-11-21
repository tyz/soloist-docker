# syntax=docker/dockerfile:1

FROM debian:trixie-slim

ARG TARGETARCH
ARG SOLOIST_VERSION=dev
LABEL org.opencontainers.image.version="${SOLOIST_VERSION}"

WORKDIR /app

# Named volumes mounted at /data (as in docker-compose.yaml) inherit this
# ownership, so the unprivileged user can store the API key and pairing data.
RUN install -d -o 1000 -g 1000 /data

ENV DEBIAN_FRONTEND=noninteractive

RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/debconf \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libatomic1 \
        libpipewire-0.3-0 \
        libpipewire-0.3-modules

COPY soloist_release_${TARGETARCH}.tar.gz /app/
RUN tar -xzf soloist_release_${TARGETARCH}.tar.gz && rm soloist_release_${TARGETARCH}.tar.gz

COPY --chmod=0755 entrypoint.sh /app/entrypoint.sh

USER 1000

ENTRYPOINT ["/app/entrypoint.sh"]
