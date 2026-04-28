# Per-user OpenClaw template

This directory ships the self-service per-user `openclaw.container` template used by the `openquad` command.

The template consumes the OpenQuad image from `ghcr.io/myos-dev/openquad:latest` by default while keeping the existing MyOS per-user service name, container name, and state paths.

It is intentionally separate from `templates/persistent-users/`:

- `openquad` installs this template on demand for the current login user
- `myos persistent-user-enroll` does not copy it automatically
- the generated Quadlet lives in `~/.config/containers/systemd/`
- user-owned runtime state lives under `~/.local/share/openclaw/` and `~/.local/state/openclaw/`
- OpenClaw listens on `127.0.0.1:18789` on the host by default
- GPU device passthrough is not enabled here by default; add explicit `/dev/dri` or `/dev/kfd` handling if you want a local GPU backend inside the container

## Local service URLs

The stock MyOS per-user template uses the host-published fallback because that matches the current live rootless Podman layout:

```text
OLLAMA_BASE_URL=http://host.containers.internal:11434
SEARXNG_BASE_URL=http://host.containers.internal:8888
```

Those URLs work when Ollama and SearXNG publish ports on the host. `localhost` inside the OpenQuad/OpenClaw container is not the host and is not a sibling container, so it is not a correct default for these services.

A shared user-defined Podman network is also supported, but MyOS does not create or manage that network in the stock per-user flow. To use service-name URLs, create a user network, attach OpenQuad/OpenClaw plus the sibling service containers to it, and change the generated Quadlet to use:

```ini
Network=openquad.network
Environment=OLLAMA_BASE_URL=http://ollama:11434
Environment=SEARXNG_BASE_URL=http://searxng:8080
```

That shared-network mode is cleaner for all-Quadlet local services, while the host-published mode is easier for an existing machine where Ollama and SearXNG already expose host ports.

Set `OPENQUAD_IMAGE` before running `openquad start` or `openquad update` to render a different image into the user Quadlet.
