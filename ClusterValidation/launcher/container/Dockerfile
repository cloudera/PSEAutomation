# syntax=docker/dockerfile:1.6
# OCI-compliant image for the ephemeral EC2 runner launcher.
# Builds with docker, podman, buildah, or buildkit.

ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim AS base

ARG IMAGE_VERSION=1.0.0
ARG IMAGE_REVISION=local
ARG IMAGE_CREATED
LABEL org.opencontainers.image.title="ephemeral-ec2-launcher" \
      org.opencontainers.image.description="Creates an ephemeral EC2 runner inside a caller-supplied VPC/subnet and emits a JSON handoff describing the resources it created." \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://example.invalid/ephemeral-ec2-launcher" \
      org.opencontainers.image.vendor="smoke-runner" \
      org.opencontainers.image.base.name="docker.io/library/python:${PYTHON_VERSION}-slim"

FROM base AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates dumb-init \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY launcher.py entrypoint.sh ./
RUN chmod 0755 entrypoint.sh launcher.py

ARG APP_UID=10001
ARG APP_GID=10001
RUN groupadd -g "${APP_GID}" runner \
    && useradd -u "${APP_UID}" -g "${APP_GID}" -m -s /usr/sbin/nologin runner \
    && chown -R runner:runner /app

USER runner:runner
ENV HOME=/home/runner \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# dumb-init handles PID 1 signal forwarding.
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/app/entrypoint.sh"]
CMD []
