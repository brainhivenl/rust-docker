# syntax=docker/dockerfile:1.4

FROM rust:slim-buster AS builder

RUN apt-get update && \
    apt-get install -y build-essential wget && \
    rm -rf /var/lib/apt/lists/*

# Install and configure sccache to speed up builds
ENV SCCACHE_VERSION=0.5.0

RUN ARCH= && alpineArch="$(dpkg --print-architecture)" \
      && case "${alpineArch##*-}" in \
        amd64) \
          ARCH='x86_64' \
          ;; \
        arm64) \
          ARCH='aarch64' \
          ;; \
        *) ;; \
      esac \
    && wget -O sccache.tar.gz https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/sccache-v${SCCACHE_VERSION}-${ARCH}-unknown-linux-musl.tar.gz \
    && tar xzf sccache.tar.gz \
    && mv sccache-v*/sccache /usr/local/bin/sccache \
    && chmod +x /usr/local/bin/sccache

ENV RUSTC_WRAPPER=/usr/local/bin/sccache

# Pre-compile dependencies
WORKDIR /build

RUN cargo init --name rust-docker

COPY Cargo.toml Cargo.lock ./

RUN --mount=type=cache,target=/root/.cache cargo fetch && \
    cargo build && \
    cargo build --release && \
    rm src/*.rs

# Build the project
COPY src src

RUN --mount=type=cache,target=/root/.cache touch src/main.rs && \
    cargo build --release

# Distribute the binary
FROM gcr.io/distroless/cc-debian11 AS release

WORKDIR /dist

COPY --link --from=builder /build/target/release/rust-docker ./rust-docker

CMD ["/dist/rust-docker"]
