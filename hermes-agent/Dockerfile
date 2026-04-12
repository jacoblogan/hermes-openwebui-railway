FROM nousresearch/hermes-agent:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates git unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://composio.dev/install | bash \
    && ln -sf /root/.composio/composio /usr/local/bin/composio

COPY start.sh /usr/local/bin/start-hermes.sh

RUN chmod +x /usr/local/bin/start-hermes.sh

EXPOSE 8642

ENTRYPOINT ["/usr/local/bin/start-hermes.sh"]
