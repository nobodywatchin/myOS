# OpenClaw tenant runtime templates

These files are examples for post-boot tenant provisioning.

- `quadlets/` contains rootless Podman unit templates.
- `scripts/` contains rendered helper entrypoints mounted into tenant services.
- `env/` contains operator-managed runtime and secret defaults.
- `storage/` documents the expected per-tenant layout.
- `trust-zones/` explains how Zone A, B, and C stay separated.
- `proxy/` contains nginx route examples that stay inactive until promoted.

By default, each tenant gets:

- a published gateway/UI port fronted by a small in-container proxy that serves the Control UI and forwards HTTP/WebSocket traffic to the internal OpenClaw gateway
- a bridge port for internal gateway bridge traffic
- a canonical `zone-c/state/openclaw.json` runtime config that is seeded once and then owned by OpenClaw and the operator
- myOS-managed host concerns for secrets, ports, storage, Quadlet rendering, backup/restore, and optional host-level Tailscale Serve exposure
- loopback-first local access; nginx routes remain a separate future ingress path, while host-managed Tailscale publishes the tenant gateway directly when enabled
- when host-managed Tailscale is enabled, myOS also writes `plugins.entries.device-pair.config.publicUrl` so plain `openclaw qr` uses the same canonical HTTPS tenant URL
