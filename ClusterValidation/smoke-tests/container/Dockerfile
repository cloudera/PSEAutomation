# syntax=docker/dockerfile:1.6
# OCI-compliant image for the Cloudera CDP smoke-test driver.
# Builds with docker, podman, buildah, or buildkit.

ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS base

ARG IMAGE_VERSION=1.0.0
ARG IMAGE_REVISION=local
ARG IMAGE_CREATED
LABEL org.opencontainers.image.title="cloudera-smoke-tests" \
      org.opencontainers.image.description="Consumes a JSON handoff from the ephemeral-ec2-launcher, runs the Cloudera CDP smoke probe via SSM, writes Nagios/Prometheus/JSON/HTML reports, and tears the runner down." \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://example.invalid/cloudera-smoke-tests" \
      org.opencontainers.image.vendor="smoke-runner" \
      org.opencontainers.image.base.name="docker.io/library/python:${PYTHON_VERSION}-slim"

FROM base AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates dumb-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY smoke.py remote_probe.py report.py entrypoint.sh ./
RUN chmod 0755 entrypoint.sh smoke.py

ARG APP_UID=10001
ARG APP_GID=10001
RUN groupadd -g "${APP_GID}" smoke \
    && useradd -u "${APP_UID}" -g "${APP_GID}" -m -s /usr/sbin/nologin smoke \
    && mkdir -p /output \
    && chown -R smoke:smoke /app /output

USER smoke:smoke
ENV OUTPUT_DIR=/output \
    HOME=/home/smoke \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

VOLUME ["/output"]

# dumb-init handles PID 1 signal forwarding (SIGTERM → graceful teardown).
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/app/entrypoint.sh"]
CMD []
