FROM nousresearch/hermes-agent:v0.23.0@sha256:adb7890916de63245523492be8f68f9d2095fecbec4e2a6dab7960381f0fc002

COPY --from=ghcr.io/astral-sh/uv:0.13.7 /uv /usr/local/bin/uv
RUN apt-get update \
    && apt-get install -y --no-install-recommends gh jq \
    && rm -rf /var/lib/apt/lists/*

ARG YT_DLP_VERSION=2026.10.21
ARG BGUTIL_VERSION=2.0.0
ARG ANYDOC_VERSION=0.2.4
ARG GRAPHIFY_VERSION=0.9.53
RUN export UV_TOOL_DIR=/opt/workspace-tools \
        UV_TOOL_BIN_DIR=/usr/local/bin \
        UV_PYTHON_INSTALL_DIR=/opt/workspace-python \
    && uv python install 3.13 \
    && uv tool install --python 3.13 \
        --with "bgutil-ytdlp-pot-provider==${BGUTIL_VERSION}" "yt-dlp[default]==${YT_DLP_VERSION}" \
    && uv tool install --python 3.13 "graphifyy==${GRAPHIFY_VERSION}" \
    && uv pip install --python /opt/hermes/.venv/bin/python 'PyYAML==6.0.3' \
    && npm install --global --prefix /usr/local "@firecrawl/anydoc@${ANYDOC_VERSION}" \
    && chmod -R a+rX /opt/workspace-tools /opt/workspace-python

COPY deploy/yt-dlp.conf /etc/yt-dlp.conf
COPY skills/mdwiki/ /opt/hermes/skills/note-taking/mdwiki/
COPY skills/research-agent/ /opt/hermes/skills/note-taking/research-agent/
COPY skills/ukrainian-summary/ /opt/hermes/skills/note-taking/ukrainian-summary/
COPY deploy/telegram-link-dedup.patch /tmp/telegram-link-dedup.patch
COPY deploy/telegram-url-summary.patch /tmp/telegram-url-summary.patch
RUN cd /opt/hermes \
    && git apply --check /tmp/telegram-link-dedup.patch \
    && git apply /tmp/telegram-link-dedup.patch \
    && git apply --check /tmp/telegram-url-summary.patch \
    && git apply /tmp/telegram-url-summary.patch \
    && rm /tmp/telegram-link-dedup.patch /tmp/telegram-url-summary.patch
