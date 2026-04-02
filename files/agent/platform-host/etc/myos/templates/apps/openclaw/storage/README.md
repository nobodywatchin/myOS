# Storage layout

Each dedicated tenant gets a root at `/srv/tenants/<tenant>/`.

- `zone-c/state/`: mounted to `/home/node/.openclaw` for OpenClaw config and state
- `zone-c/storage/`: tenant-owned durable application storage mounted at `/home/node/.openclaw/workspace`
- `zone-c/secrets/`: tenant-local env files, provider keys, and gateway token
- `logs/`: persistent container log directory mounted at `/tmp/openclaw`
- `config/`: rendered env, proxy, firewall, and DNS policy files

The current tenant model is a single dedicated service account with one OpenClaw runtime container. Persistent login-user services are tracked separately through `/etc/myos/persistent-users/` and the user's own `~/.config/containers/systemd/` tree.
