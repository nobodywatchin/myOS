# Deployment shape

The tenant template tree now runs a single rootless OpenClaw gateway container.
This directory name is retained for compatibility with the older docs structure,
but the active model is the simpler current tenant layout rather than a multi-zone
service split.

- `zone-c/state/` holds the OpenClaw config tree mounted at `/home/node/.openclaw`.
- `zone-c/storage/` holds the persistent workspace mounted at `/home/node/.openclaw/workspace`.
- `zone-c/secrets/` stays outside the config tree for host-managed env files.
