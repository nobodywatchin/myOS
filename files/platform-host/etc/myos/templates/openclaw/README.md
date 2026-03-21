# OpenClaw tenant runtime templates

These files are examples for post-boot tenant provisioning.

- `quadlets/` contains rootless Podman unit templates.
- `scripts/` contains rendered helper entrypoints mounted into tenant services.
- `env/` contains operator-managed runtime and secret defaults.
- `storage/` documents the expected per-tenant layout.
- `trust-zones/` explains how Zone A, B, and C stay separated.
- `proxy/` contains nginx route examples that stay inactive until promoted.

By default, each tenant gets:

- a gateway port for CLI and WebSocket access
- a bridge port for internal gateway bridge traffic
- a dedicated loopback Control UI port that serves the browser UI through a
  local proxy
- a generated `openclaw.json` rendered from tenant env settings rather than
  hand-edited state files
