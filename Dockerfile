# syntax=docker/dockerfile:1

FROM debian:trixie-slim

WORKDIR /app

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

RUN curl -sfL https://soloist-builds.spotifycdn.com/soloist_release_arm64.tar.gz | tar -xzf -

ENTRYPOINT ["/app/soloist"]
