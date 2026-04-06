# Deployment shape

The tenant template tree now runs a single rootless OpenClaw gateway container.
This directory name is retained for compatibility with older docs, but the
active model is a simple single-runtime layout rather than a live multi-zone
service split.

What still matters:

- `zone-c/state/` holds the OpenClaw config tree mounted at `/home/node/.openclaw`.
- `zone-c/storage/` holds the persistent workspace mounted at `/home/node/.openclaw/workspace`.
- `zone-c/secrets/` stays outside the config tree for host-managed env files.

What does **not** matter anymore:

- the `zone-c` label itself is not a special trust boundary or scheduler concept
- operators should think in terms of state vs workspace vs secrets, not named zones
