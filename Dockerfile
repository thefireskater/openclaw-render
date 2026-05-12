# Global ARG for use in FROM instructions
ARG OPENCLAW_VERSION=latest

# Build Go proxy
FROM golang:1.22-bookworm AS proxy-builder

WORKDIR /proxy
COPY proxy/ .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /proxy-bin .


# Extend pre-built OpenClaw with our auth proxy
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

# Base image ends with USER node; switch to root for setup
USER root

# Add packages for openclaw agent operations
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libasound2 \
    libatspi2.0-0 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxatspi0 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Add proxy
COPY --from=proxy-builder /proxy-bin /usr/local/bin/proxy

# Create CLI wrapper (openclaw code is at /app/dist/index.js in base image)
RUN printf '#!/bin/sh\nexec node /app/dist/index.js "$@"\n' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

# Gateway is Node; match render.yaml / NODE_OPTIONS (override via Render env).
ENV NODE_OPTIONS="--max-old-space-size=3072"

ENV PORT=10000
EXPOSE 10000

# Run as non-root for security (matching base image)
USER node

CMD ["/usr/local/bin/proxy"]
