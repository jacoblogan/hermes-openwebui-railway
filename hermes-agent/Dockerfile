FROM nousresearch/hermes-agent:latest

# Upstream entrypoint activates the venv; we replace it with start-hermes.sh, so
# keep the CLI on PATH for subprocesses and predictable resolution.
ENV PATH="/opt/hermes/.venv/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates git unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://composio.dev/install | bash \
    && ln -sf /root/.composio/composio /usr/local/bin/composio

COPY start.sh /usr/local/bin/start-hermes.sh

RUN chmod +x /usr/local/bin/start-hermes.sh

EXPOSE 8642

ENTRYPOINT ["/usr/local/bin/start-hermes.sh"]
