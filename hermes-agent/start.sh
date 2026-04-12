#!/bin/sh
set -eu

: "${API_SERVER_ENABLED:=true}"
: "${API_SERVER_HOST:=::}"
: "${API_SERVER_PORT:=8642}"
: "${TERMINAL_BACKEND:=local}"
: "${HOME:=/root}"
: "${HERMES_HOME:=${HOME}/.hermes}"
: "${MEMORY_PROVIDER:=supermemory}"
: "${COMPOSIO_AUTH_HEADER_NAME:=X-Consumer-API-Key}"
: "${OPENROUTER_MODEL:=qwen/qwen3.6-plus:free}"
: "${HERMES_MODEL_EXTRA_YAML:=}"
: "${OPENROUTER_PROVIDER_ROUTING_YAML:=}"
: "${HERMES_CONFIG_EXTRA_YAML:=}"

CONFIG_PATH="${HERMES_HOME}/config.yaml"
TEMPLATE_MARKER="# Managed by hermes-openwebui-railway template"

if [ -z "${API_SERVER_KEY:-}" ]; then
  echo "API_SERVER_KEY must be set" >&2
  exit 1
fi

case "${MEMORY_PROVIDER}" in
  holographic|supermemory)
    ;;
  *)
    echo "Unsupported MEMORY_PROVIDER: ${MEMORY_PROVIDER}" >&2
    echo "Use one of: holographic, supermemory" >&2
    exit 1
    ;;
esac

if [ "${MEMORY_PROVIDER}" = "supermemory" ] && [ -z "${SUPERMEMORY_API_KEY:-}" ]; then
  echo "SUPERMEMORY_API_KEY must be set when MEMORY_PROVIDER=supermemory" >&2
  exit 1
fi

mkdir -p "${HERMES_HOME}"

login_composio_cli() {
  if ! command -v composio >/dev/null 2>&1; then
    return 0
  fi

  if [ -z "${COMPOSIO_API_KEY:-}" ]; then
    return 0
  fi

  echo "Configuring Composio CLI auth" >&2

  if [ -n "${COMPOSIO_ORG:-}" ]; then
    if ! composio login --user-api-key "${COMPOSIO_API_KEY}" --org "${COMPOSIO_ORG}" -y --no-skill-install >/dev/null 2>&1; then
      echo "Failed to configure Composio CLI for org ${COMPOSIO_ORG}" >&2
      return 1
    fi
    return 0
  fi

  if ! composio login --user-api-key "${COMPOSIO_API_KEY}" -y --no-skill-install >/dev/null 2>&1; then
    echo "Failed to configure Composio CLI" >&2
    return 1
  fi
}

COMPOSIO_HEADER_VALUE="${COMPOSIO_CONSUMER_API_KEY:-}"

if [ -n "${COMPOSIO_MCP_URL:-}" ] && [ -z "${COMPOSIO_HEADER_VALUE}" ]; then
  echo "COMPOSIO_MCP_URL is set, but no Composio auth header value was provided" >&2
  echo "Set COMPOSIO_CONSUMER_API_KEY" >&2
  exit 1
fi

if [ -n "${COMPOSIO_HEADER_VALUE}" ] && [ -z "${COMPOSIO_MCP_URL:-}" ]; then
  echo "A Composio auth header value is set, but COMPOSIO_MCP_URL is missing" >&2
  exit 1
fi

append_indented_yaml() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1" | sed 's/^/  /'
  fi
}

append_raw_yaml() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
  fi
}

write_config() {
  cat <<EOF
${TEMPLATE_MARKER}
model:
  provider: openrouter
  default: ${OPENROUTER_MODEL}
EOF

  append_indented_yaml "${HERMES_MODEL_EXTRA_YAML}"

  cat <<EOF
memory:
  provider: ${MEMORY_PROVIDER}
EOF

  if [ "${MEMORY_PROVIDER}" = "holographic" ]; then
    cat <<EOF
plugins:
  hermes-memory-store:
    db_path: ${HERMES_HOME}/memory_store.db
EOF
  fi

  if [ -n "${OPENROUTER_PROVIDER_ROUTING_YAML}" ]; then
    cat <<EOF
provider_routing:
EOF
    append_indented_yaml "${OPENROUTER_PROVIDER_ROUTING_YAML}"
  fi

  if [ -n "${COMPOSIO_MCP_URL:-}" ]; then
    cat <<EOF
mcp_servers:
  composio:
    url: "${COMPOSIO_MCP_URL}"
    headers:
      ${COMPOSIO_AUTH_HEADER_NAME}: "${COMPOSIO_HEADER_VALUE}"
    enabled: true
    timeout: 120
    connect_timeout: 60
    tools:
      resources: false
      prompts: false
EOF
  fi

  append_raw_yaml "${HERMES_CONFIG_EXTRA_YAML}"
}

if [ ! -f "${CONFIG_PATH}" ] || grep -qF "${TEMPLATE_MARKER}" "${CONFIG_PATH}"; then
  if [ -z "${OPENROUTER_API_KEY:-}" ]; then
    echo "OPENROUTER_API_KEY must be set for the template-managed OpenRouter model" >&2
    exit 1
  fi

  if [ -z "${OPENROUTER_MODEL}" ]; then
    echo "OPENROUTER_MODEL must be set" >&2
    exit 1
  fi

  write_config > "${CONFIG_PATH}"
fi

login_composio_cli

exec hermes gateway
