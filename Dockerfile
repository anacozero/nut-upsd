# syntax=docker/dockerfile:1

# Base image is pinned by digest for reproducible, tamper-evident builds.
# Dependabot keeps the tag + digest current (see .github/dependabot.yml), which
# is also how NUT itself is updated: security fixes arrive as Alpine package
# revisions, feature versions arrive with a new Alpine release.
ARG ALPINE_VERSION=3.24
ARG ALPINE_DIGEST=sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST}

LABEL org.opencontainers.image.title="nut-upsd" \
      org.opencontainers.image.description="Network UPS Tools (NUT) server for USB-attached UPS monitoring" \
      org.opencontainers.image.licenses="GPL-2.0-or-later"

# NUT looks up its runtime state directory from this variable (the driver and
# upsd rendezvous here); pinning it keeps behaviour independent of the package's
# compiled default.
ENV UPS_NAME="ups" \
    UPS_DESC="UPS" \
    UPS_DRIVER="usbhid-ups" \
    UPS_PORT="auto" \
    SHUTDOWN_CMD="echo 'System shutdown not configured!'" \
    NUT_STATEPATH="/var/run/nut"

# nut:            NUT server, drivers and clients (Alpine community package,
#                 which also creates the unprivileged `nut` user the daemons
#                 drop to).
# openssh-client: lets SHUTDOWN_CMD reach remote hosts over SSH.
# tini:           minimal PID 1 for signal forwarding and zombie reaping.
# hadolint ignore=DL3018
RUN set -eux; \
	apk add --no-cache \
		nut \
		openssh-client \
		tini \
	; \
	install -d -m 750 -o nut -g nut "$NUT_STATEPATH"

COPY docker-entrypoint /usr/local/bin/

# Treat an unreadable UPS as unhealthy (upsc talks to upsd on 3493).
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
	CMD upsc "${UPS_NAME}@localhost" >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/sbin/tini", "--", "docker-entrypoint"]

WORKDIR /var/run/nut

EXPOSE 3493
