# Deployment shape

The tenant template tree now runs a single rootless OpenClaw gateway container.

- `zone-c/state/` holds the OpenClaw config tree mounted at `/home/node/.openclaw`.
- `zone-c/storage/` holds the persistent workspace mounted at `/home/node/.openclaw/workspace`.
- `zone-c/secrets/` stays outside the config tree for host-managed env files.
