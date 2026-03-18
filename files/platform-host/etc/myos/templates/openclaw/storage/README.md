# Storage layout

Each tenant gets a root at `/srv/tenants/<tenant>/`.

- `zone-a/openclaw/`: trusted agent and OpenClaw runtime state
- `zone-b/browser/`: hostile-input browser profile and automation data
- `zone-b/parser/`: parser worker scratch space
- `zone-b/downloads/`: quarantined file landing zone
- `zone-c/storage/`: tenant-owned durable application storage
- `zone-c/secrets/`: tenant-local secret files
- `config/`: rendered env, proxy, firewall, and DNS policy files
