# Per-user OpenClaw template

This directory ships the self-service per-user `openclaw.container` template.

It is intentionally separate from `templates/persistent-users/`:

- `openquad` installs this template on demand for the current login user
- `myos persistent-user-enroll` does not copy it automatically
- the generated Quadlet lives in `~/.config/containers/systemd/`
- user-owned runtime state lives under `~/.local/share/openclaw/` and `~/.local/state/openclaw/`
- GPU device passthrough is not enabled here by default; add explicit `/dev/dri`
  or `/dev/kfd` handling if you want a local GPU backend inside the container
