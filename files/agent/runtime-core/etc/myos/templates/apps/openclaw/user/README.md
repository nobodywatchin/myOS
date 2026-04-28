# Per-user OpenClaw template

This directory ships the self-service per-user `openclaw.container` template used by the `openquad` command.

The template consumes the OpenQuad image from `ghcr.io/myos-dev/openquad:latest` by default while keeping the existing MyOS per-user service name, container name, and state paths.

It is intentionally separate from `templates/persistent-users/`:

- `openquad` installs this template on demand for the current login user
- `myos persistent-user-enroll` does not copy it automatically
- the generated Quadlet lives in `~/.config/containers/systemd/`
- user-owned runtime state lives under `~/.local/share/openclaw/` and `~/.local/state/openclaw/`
- OpenClaw listens on `127.0.0.1:18789` on the host by default
- local Ollama and SearXNG defaults use `host.containers.internal` because the current MyOS per-user flow uses rootless slirp networking rather than a managed sibling-container bridge
- GPU device passthrough is not enabled here by default; add explicit `/dev/dri` or `/dev/kfd` handling if you want a local GPU backend inside the container

Set `OPENQUAD_IMAGE` before running `openquad start` or `openquad update` to render a different image into the user Quadlet.
