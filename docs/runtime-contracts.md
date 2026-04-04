# myOS Runtime Contracts

This document records the current runtime contracts that matter when editing the
repo.

It is intentionally narrower than product vision:

- which paths are authoritative
- which paths are image-provided versus mutable
- who owns the state under those paths
- which services and commands are expected to touch them
- what a healthy deployment looks like

When a change moves a path, renames a service, changes an env contract, or
changes which actor owns a directory, treat it as a contract change and update
this file.

## Runtime planes

myOS currently ships three runtime planes:

1. **Dedicated tenant accounts**
   - managed through `myos tenant-*`
   - each tenant is a separate rootless service account under `/srv/tenants/<tenant>/`

2. **Persistent login users**
   - managed through `myos persistent-user-*`
   - each enrolled user keeps their real home directory and their own user systemd manager

3. **Shared host RamaLama service**
   - managed through `myos-ramalama@.service`
   - runs as the dedicated `modelsvc` account

These planes intentionally share some image-provided scaffolding, but they do
not share mutable runtime state.

## Contract classes

### Image-provided substrate

These are shipped in the image and are expected to be replaced by image
upgrades, not hand-mutated as live state:

- `/usr/local/bin/openclaw`
- `/usr/local/bin/openquad`
- `/usr/local/libexec/myos/`
- `/etc/myos/templates/apps/openclaw/`
- `/etc/myos/templates/persistent-users/`
- `/usr/lib/systemd/system/myos-ramalama@.service`
- `/etc/nginx/conf.d/myos-platform.conf`

Rule:

- do not store live tenant data, live user state, or real secrets here
- if operators need mutable state, it belongs under `/etc/myos/**`, `/srv/**`,
  `/var/lib/**`, or the real user home directory depending on the plane

### Host-managed mutable state

These are writable, operator-facing paths that survive upgrades:

- `/etc/myos/tenants/ports.state`
- `/etc/myos/proxy/tenants/`
- `/etc/myos/firewall/rendered/`
- `/etc/myos/persistent-users/`
- `/etc/myos/ramalama/models/*.env`
- `/srv/models/ramalama`
- `/srv/tenants/<tenant>/`
- `/var/lib/modelsvc`
- `/var/tmp/myos-podman/<tenant>/storage`

### User-managed mutable state

These are intentionally outside the admin-managed state tracker and belong to
real login users:

- `~/.config/containers/systemd/`
- `~/.config/myos/`
- `~/.local/share/openclaw/`
- `~/.local/state/openclaw/logs/`

Rule:

- admin-managed template reconciliation may install baseline files into the
  user's Quadlet directory, but it must not erase unrelated self-service files
  there

## Shared host substrate contracts

### `/etc/myos/`

This is the root for host-side myOS state and templates.

Key subtrees:

- `/etc/myos/templates/apps/openclaw/`
  - image-provided tenant template tree
- `/etc/myos/templates/persistent-users/`
  - image-provided persistent-user template buckets
- `/etc/myos/persistent-users/`
  - admin-managed persistent-user state tracking
- `/etc/myos/tenants/`
  - shared tenant allocation state such as `ports.state`
- `/etc/myos/proxy/`
  - host-managed nginx route fragments and metadata
- `/etc/myos/firewall/`
  - rendered firewall plans
- `/etc/myos/ramalama/`
  - host-managed shared RamaLama instance configs

Ownership expectations:

- root-owned
- templates are image content
- rendered state files are host mutable content

### `/var/tmp/myos-podman`

This is the shared rootless Podman storage parent used by the dedicated tenant
plane.

Current tenant contract:

- per-tenant graphroot: `/var/tmp/myos-podman/<tenant>/storage`

This path is part of the tenant runtime contract and should not move casually.
`tenant-validate` checks that the tenant's `storage.conf` points at this exact
location.

### `/etc/nginx/conf.d/myos-platform.conf`

This is a loopback-only substrate server, not a live tenant route by itself.

Contract:

- loopback listener on `127.0.0.1:8088`
- `/healthz` returns `200 ok`
- reviewed tenant route fragments live under `/etc/myos/proxy/tenants/*.conf`

## Dedicated tenant contract

The dedicated tenant plane is the persistent, service-account path for hosted
OpenClaw gateways.

### Identity and home

Each tenant is a real local account with:

- user name: `<tenant>`
- home directory: `/srv/tenants/<tenant>/home`
- shell: `/usr/sbin/nologin`

`myos tenant-*` owns this contract.

### Authoritative tenant root

Each tenant's mutable state is rooted at:

- `/srv/tenants/<tenant>/`

Current required subtrees:

- `config/`
  - rendered env files and host policy artifacts
- `config/env/`
  - `common.env`, `openclaw.env`, `ports.env`
- `config/rendered/`
  - rendered startup helpers such as `openclaw-start.sh`
- `zone-c/state/`
  - mounted into the container as `/home/node/.openclaw`
- `zone-c/storage/`
  - mounted into the container as `/home/node/.openclaw/workspace`
- `zone-c/secrets/`
  - host-managed provider secrets and gateway token
- `logs/`
  - persistent container log volume
- `home/.config/containers/systemd/openclaw.container`
  - rendered rootless Quadlet owned by the tenant account

Important env contracts:

- tenant runtime config file: `/srv/tenants/<tenant>/zone-c/state/openclaw.json`
- tenant secret file: `/srv/tenants/<tenant>/zone-c/secrets/openclaw.secrets.env`
- gateway port source of truth: `/srv/tenants/<tenant>/config/env/ports.env`

### Service contract

The dedicated tenant runtime is a generated user unit:

- service name: `openclaw.service`
- container name: `openclaw-<tenant>`
- service owner: tenant account user systemd manager

The image-provided Quadlet template lives at:

- `/etc/myos/templates/apps/openclaw/quadlets/openclaw.container`

The rendered tenant Quadlet is expected at:

- `/srv/tenants/<tenant>/home/.config/containers/systemd/openclaw.container`

### Tenant health contract

`myos tenant-validate --tenant <name>` is the supported validation surface.

Healthy tenant state means at least:

- tenant account exists
- tenant root directories exist
- rendered env files exist
- rendered Quadlet exists
- Podman graphroot matches `/var/tmp/myos-podman/<tenant>/storage`
- gateway token exists in the secret env file
- `openclaw config validate --json` succeeds in tenant context

If `--require-running` is used, healthy also means:

- `openclaw.service` is active
- container exists and is running
- configured loopback ports are listening
- dashboard endpoint responds
- optional Tailscale exposure matches the rendered config

## Persistent login-user contract

This plane is for real login users that an admin explicitly enrolls for
background rootless services.

### Enrollment-owned paths

Admin-managed state root:

- `/etc/myos/persistent-users/`

Current state files:

- `owner.conf`
- `users/<name>/baseline.files`
- `users/<name>/baseline.units`
- `users/<name>/owner.files`
- `users/<name>/owner.units`

These files are authoritative for what the admin-managed reconciliation logic
installed for that user.

### User-home contract

For an enrolled login user, current expected paths are:

- `~/.config/containers/systemd/openclaw.container`
- `~/.config/myos/`
- `~/.local/share/openclaw/`
- `~/.local/share/openclaw/openclaw.json`
- `~/.local/share/openclaw/workspace/`
- `~/.local/state/openclaw/logs/`

Important distinction:

- `~/.config/containers/systemd/` is the supported self-service Quadlet path
- admin-managed baseline and owner templates may place files there, and `openquad` may install the per-user OpenClaw Quadlet there on demand
- unrelated user-created Quadlets in that directory are still user-owned

### Service contract

The per-user OpenClaw runtime is also a generated user unit:

- service name: `openclaw.service`
- container name: `openclaw`
- wrapper CLI: `openquad`
- workload CLI: `openclaw`

The shipped per-user template lives at:

- `/etc/myos/templates/apps/openclaw/user/openclaw.container`

The wrapper boundary is intentional:

- `openquad` owns lifecycle (`start`, `stop`, `restart`, `status`, `logs`, `doctor`, `inspect`)
- `openclaw` only execs into an already-running runtime
- `openclaw` must not auto-start the runtime silently

### Persistent-user health contract

Supported checks:

- `myos persistent-user-validate --user <name>`
- `openquad doctor`

Healthy enrolled-user state means at least:

- login user exists with a valid home directory
- `subuid` and `subgid` ranges exist
- lingering is enabled if persistence is expected across logout
- user systemd is reachable
- managed baseline files exist
- generated user service is installed
- runtime directories are present and writable

For a running runtime, healthy also means:

- `openclaw.service` is active in the user manager
- the `openclaw` container is running
- the inner `openclaw` binary exists
- first-run config has either been completed or the runtime is clearly in onboarding mode

## Shared RamaLama contract

The shared model-host plane is the dedicated `modelsvc` account.

### Identity and state

Account:

- user: `modelsvc`
- group: `modelsvc`

Authoritative mutable paths:

- service home: `/var/lib/modelsvc`
- shared model store: `/srv/models/ramalama`
- instance env files: `/etc/myos/ramalama/models/<instance>.env`
- runtime dir: `/run/myos-modelsvc`

The image creates the directories and ownership baseline; operators provide the
instance env files and enable the service explicitly.

### Service contract

System service template:

- `myos-ramalama@.service`

Launcher:

- `/usr/local/libexec/myos/ramalama-serve`

Current expectations from `ramalama-serve`:

- `MODEL_REF` must be set in the instance env file
- the image must actually include the `ramalama` binary
- loopback binding is preferred through `RAMALAMA_HOST=127.0.0.1`
- wide binding is refused unless `RAMALAMA_ALLOW_WIDE_BIND=1`

### RamaLama health contract

Healthy instance state means at least:

- `/etc/myos/ramalama/models/<instance>.env` exists
- `ramalama` is installed in the image variant
- `myos-ramalama@<instance>.service` starts cleanly
- the service only binds as widely as the config explicitly allows
- `/var/lib/modelsvc` and `/srv/models/ramalama` remain writable by `modelsvc`

## Ownership boundaries and safe mutation

### Safe to change with repo edits

- shipped templates
- shipped helper scripts
- systemd unit templates and drop-ins
- path documentation and validation docs

### Host/operator-managed at runtime

- tenant env files under `/srv/tenants/<tenant>/config/env/`
- tenant secret files under `/srv/tenants/<tenant>/zone-c/secrets/`
- persistent-user enrollment state under `/etc/myos/persistent-users/`
- RamaLama instance env files under `/etc/myos/ramalama/models/`
- active proxy fragments under `/etc/myos/proxy/tenants/`

### Must not be treated as generic scratch space

- `/etc/myos/templates/**`
- `/srv/models/ramalama`
- `/srv/tenants/<tenant>/zone-c/state`
- `/srv/tenants/<tenant>/zone-c/storage`
- `~/.local/share/openclaw/`

If you need new runtime state, give it an explicit owner and document whether it
belongs to the image, the host operator, the tenant account, the enrolled login
user, or the shared `modelsvc` service.
