# Tenant state and secrets

Use these paths for the official single-container OpenClaw deployment.

- `zone-c/state/` maps to `/home/node/.openclaw` for config, auth, and runtime state.
- `zone-c/storage/` maps to `/home/node/.openclaw/workspace` for durable workspace data.
- `zone-c/secrets/` is for env files and provider credentials supplied by the host.

The split is still useful because it keeps mutable runtime state, durable
workspace content, and host-managed secrets separate for mounting, backup, and
permission handling. The `zone-c` name itself is just legacy compatibility
naming.
