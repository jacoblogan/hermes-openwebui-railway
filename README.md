# Hermes Agent + Open WebUI Railway Template

This repo is a two-service Railway template that wires [Hermes Agent](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/open-webui/) to Open WebUI over Railway private networking.

The setup follows the Hermes Open WebUI guide:

- Hermes runs its OpenAI-compatible API server.
- Open WebUI connects to Hermes at the Hermes service's internal `/v1` endpoint.
- Both services share the same non-empty API key.
- Hermes uses OpenRouter for its main model, configured entirely from service env vars.
- Hermes seeds `memory.provider: supermemory` on first boot when `SUPERMEMORY_API_KEY` is set.
- Hermes can optionally use Composio either through a remote MCP server or through the Composio CLI installed in the Hermes image.

## Repo Layout

- `hermes-agent/`: private Hermes API service
- `open-webui/`: public Open WebUI service
- `docker-compose.yml`: local parity stack

## Railway Template Setup

Create a Railway project from this repo with two services:

1. Add a service from `hermes-agent/` and name it `hermes`.
2. Add a service from `open-webui/` and name it `open-webui`.
3. Enable public networking only for `open-webui`.
4. Leave `hermes` private.

Attach persistent volumes:

- `hermes` -> `/root/.hermes`
- `open-webui` -> `/app/backend/data`

The Hermes volume now persists:

- `config.yaml` with the template-managed memory provider
- the rest of Hermes state under `~/.hermes`

Create one shared secret and reference it from both services:

- `HERMES_API_KEY`: any long random string
- `OPENROUTER_API_KEY`: your OpenRouter key

`HERMES_API_KEY` and `OPENROUTER_API_KEY` are also listed in the repo's root `.env.example`, so Railway can suggest them during template setup.

Set these variables on `hermes`:

- `API_SERVER_ENABLED=true`
- `API_SERVER_HOST=::`
- `API_SERVER_PORT=8642`
- `API_SERVER_KEY=${{shared.HERMES_API_KEY}}`
- `TERMINAL_BACKEND=local`
- `OPENROUTER_API_KEY=${{shared.OPENROUTER_API_KEY}}`
- `OPENROUTER_MODEL=qwen/qwen3.6-plus`
- `MEMORY_PROVIDER=supermemory`
- `SUPERMEMORY_API_KEY=...`

Optional model tuning variables:

- `HERMES_MODEL_EXTRA_YAML=`
- `OPENROUTER_PROVIDER_ROUTING_YAML=`
- `HERMES_CONFIG_EXTRA_YAML=`

`HERMES_MODEL_EXTRA_YAML` is appended under the `model:` block in `~/.hermes/config.yaml`. Use it for settings like `temperature`, `max_tokens`, or `context_length`.

`OPENROUTER_PROVIDER_ROUTING_YAML` is appended under a top-level `provider_routing:` block. Use it for OpenRouter routing settings like `sort`, `only`, or `ignore`.

`HERMES_CONFIG_EXTRA_YAML` is appended raw at the end of the generated Hermes config as a broader escape hatch.

Optional Composio variables for a single-user "Composio For You" setup:

- `COMPOSIO_MCP_URL=...`
- `COMPOSIO_API_KEY=...`
- `COMPOSIO_ORG=...`
- `COMPOSIO_CONSUMER_API_KEY=...`
- `COMPOSIO_AUTH_HEADER_NAME=x-api-key`

If your Composio setup tells you to use a different header name, set `COMPOSIO_AUTH_HEADER_NAME` accordingly.

For CLI-based Composio usage, set `COMPOSIO_API_KEY`, optionally set `COMPOSIO_ORG`, and leave `COMPOSIO_MCP_URL` unset. The Hermes image installs the `composio` CLI at build time, exposes it on `PATH`, and performs a non-interactive `composio login` during startup.

Set these variables on `open-webui`:

- `OPENAI_API_BASE_URL=http://${{hermes.RAILWAY_PRIVATE_DOMAIN}}:8642/v1`
- `OPENAI_API_KEY=${{shared.HERMES_API_KEY}}`

After deploy:

1. Open the `open-webui` public domain.
2. Create the initial admin user.
3. Start a chat and choose the Hermes-backed model exposed by the API.

## Local Development

Create a `.env` file:

```env
HERMES_API_KEY=change-me
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_MODEL=qwen/qwen3.6-plus
MEMORY_PROVIDER=supermemory
SUPERMEMORY_API_KEY=
HERMES_MODEL_EXTRA_YAML=
OPENROUTER_PROVIDER_ROUTING_YAML=
HERMES_CONFIG_EXTRA_YAML=
COMPOSIO_MCP_URL=
COMPOSIO_API_KEY=
COMPOSIO_ORG=
COMPOSIO_CONSUMER_API_KEY=
COMPOSIO_AUTH_HEADER_NAME=x-api-key
```

Then run:

```bash
docker compose up --build
```

Open WebUI will be available at `http://localhost:3000`.

## Notes

- The template-managed config supports `MEMORY_PROVIDER=holographic` and `MEMORY_PROVIDER=supermemory`. When `MEMORY_PROVIDER=supermemory`, `SUPERMEMORY_API_KEY` is required.
- The Hermes image installs the Composio CLI from `https://composio.dev/install` and exposes it as `composio` for terminal-driven workflows.
- Hermes is configured to listen on `::` so it works with Railway's current dual-stack private networking and older IPv6-only environments.
- Open WebUI reads its OpenAI connection settings from env on startup, so set the variables before first launch.
- Hermes is intentionally meant to stay on the private network in this template.
- `hermes-agent/start.sh` writes `~/.hermes/config.yaml` when the file is missing, and rewrites it only while the template marker comment remains in place. Remove the marker if you want to take over the Hermes config manually.
- The template-managed Hermes config expects `OPENROUTER_API_KEY` to be present. If you want to manage the provider setup yourself, remove the marker comment from `~/.hermes/config.yaml` and edit the file directly.
- Composio is optional. If `COMPOSIO_MCP_URL` is unset, Hermes boots without the `composio` MCP server.
- If `COMPOSIO_MCP_URL` is set, the template requires `COMPOSIO_CONSUMER_API_KEY`.
