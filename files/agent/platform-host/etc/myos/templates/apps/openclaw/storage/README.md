# Storage layout

Each dedicated tenant gets a root at `/srv/tenants/<tenant>/`.

The practical split is:

- runtime state: `zone-c/state/` → `/home/node/.openclaw`
- durable workspace data: `zone-c/storage/` → `/home/node/.openclaw/workspace`
- host-managed secrets: `zone-c/secrets/`
- persistent container logs: `logs/` → `/tmp/openclaw`
- rendered env and host policy artifacts: `config/`

The current tenant model is a single dedicated service account with one OpenClaw runtime container. The `zone-c/*` names are legacy path labels; the important contract is the separation between state, workspace, and secrets rather than the zone name itself. Persistent login-user services are tracked separately through `/etc/myos/persistent-users/` and the user's own `~/.config/containers/systemd/` tree.
