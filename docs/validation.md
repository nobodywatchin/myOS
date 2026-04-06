# myOS Validation Guide

This document records the current validation path for repo changes.

The goal is not to run every possible check every time.
The goal is to run the smallest set of checks that meaningfully prove a change
still matches the current myOS contracts.

## Validation layers

Use three layers of validation in this order:

1. **Repo-local static checks**
   - syntax
   - file wiring
   - rendered examples
2. **Booted image or host smoke checks**
   - service reachability
   - path ownership assumptions
   - runtime behavior
3. **CI / build checks**
   - legacy NVIDIA transaction verification
   - image build matrix

## First pass: repo-local static checks

Run these before asking the build pipeline to prove runtime behavior.

### Universal checks

```bash
git diff --check
```

If shell files changed:

```bash
find files/agent/platform-host/usr/local/libexec/myos -type f -print0 | xargs -0 -n1 bash -n
bash -n files/agent/platform-host/usr/local/bin/openquad
bash -n files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-start.sh
bash -n files/scripts/just-el9.sh
bash -n modules/os-release-meta/os-release-meta.sh
```

If the tenant UI helper changed:

```bash
node --check files/agent/platform-host/etc/myos/templates/apps/openclaw/scripts/openclaw-ui-server.mjs
```

If the example OpenClaw config changed:

```bash
python3 -m json.tool files/agent/platform-host/etc/myos/templates/apps/openclaw/config/openclaw.json.example >/dev/null
```

If the `just` entrypoints changed, confirm the import surface still matches the
current supported command model:

```bash
grep -q "import '/usr/share/myos/just/rebase.just'" files/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/tenant.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q "import '/usr/share/myos/just/openclaw-host.just'" files/agent/justfiles/usr/share/myos/just/index.just
grep -q '^tenant-list ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-dashboard ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-config ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-models ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-openclaw ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^tenant-tailscale ' files/agent/justfiles/usr/share/myos/just/tenant.just
grep -q '^openclaw-host ' files/agent/justfiles/usr/share/myos/just/openclaw-host.just
```

### Optional local parse checks

Use these only if the tooling exists in the current environment.

- YAML parse check for touched recipes or module metadata
- containerfile linting if available
- `shellcheck` for touched shell scripts

The repo should not depend on these being installed everywhere.

## CI-backed checks

Current build workflow lives in:

- `.github/workflows/build.yml`

### `validate-runtime-artifacts`

This job is the current static contract check for:

- host-side shell helper syntax
- tenant template helper syntax
- Alma 9 helper script syntax
- UI helper syntax
- example OpenClaw config JSON validity
- host-side shell helper syntax
- tenant and per-user Quadlet template sanity checks
- `just` import wiring
- `os-release-meta` syntax

The workflow runs the repo-local helper:

- for `myos-ramalama@.service`, this is repo-local field/contract validation rather than host-root `systemd-analyze verify`, because CI is checking staged image payloads rather than files already installed under `/`.

```bash
bash ./scripts/validate-runtime-artifacts.sh
```

If you touch any of those areas, make sure your local validation at least covers
the same surface.

### `validate-alma9-nvidia-legacy`

This job runs:

```bash
pwsh ./scripts/verify-alma9-nvidia-legacy.ps1
```

What it proves:

- Alma 9 legacy stream stays pinned to `nvidia-driver:580`
- the layer does not float to `latest`
- dependency resolution produces prebuilt proprietary kmods
- dependency resolution does not fall back to DKMS

Notes:

- requires `pwsh`
- requires either `podman` or `docker` locally

### Image build matrix

Current CI builds these image families:

- `core-full-alma9`
- `core-full-alma9-nvidia-open`
- `core-full-alma9-nvidia-legacy`
- `core-full-alma10`
- `core-full-alma10-nvidia-open`
- `gnome-alma9`
- `gnome-alma9-nvidia-open`
- `gnome-alma9-nvidia-legacy`
- `gnome-alma10`
- `gnome-alma10-nvidia-open`

Important repo behavior:

- GNOME jobs wait for the full core image jobs
- GNOME recipes build from published `core-full-*` images
- docs-only pushes do **not** trigger this workflow because `push.paths-ignore`
  excludes `**.md`

So if a docs change is tightly coupled to runtime behavior, do not assume CI will
exercise it automatically.

## Change-specific validation

### Shared recipe or layer changes

Minimum:

```bash
git diff --check
```

Then manually inspect:

- touched image recipe order
- `from-file:` layering sequence
- whether a change really belongs in `shared/` or should stay in `alma9/` or `alma10/`
- whether `docs/alma-drift.md` needs updating

If NVIDIA legacy changed, also run:

```bash
pwsh ./scripts/verify-alma9-nvidia-legacy.ps1
```

### Host helper or template changes

Run the static checks from the first-pass section.

If the change touches:

- `files/agent/platform-host/usr/local/libexec/myos/**`
- `files/agent/platform-host/etc/myos/templates/**`
- `files/agent/platform-host/usr/local/bin/openquad`
- `files/scripts/just-el9.sh`
- `files/agent/platform-host/etc/myos/templates/apps/openclaw/quadlets/openclaw.container`
- `files/agent/platform-host/etc/myos/templates/apps/openclaw/user/openclaw.container`

then treat runtime validation as required, not optional.

### Tenant runtime changes

On a booted image or host, validate the dedicated tenant plane.

Prefer the supported tenant operator surface for setup and lifecycle checks.
Treat low-level `tenant-*` reconciliation helpers under `/usr/local/libexec/myos/`
as implementation details unless you are explicitly debugging the tenant plumbing.

Recommended flow:

```bash
myos tenant-create --tenant demo
myos tenant-configure --tenant demo --model openrouter/anthropic/claude-sonnet-4-5
myos tenant-secret-set --tenant demo --key OPENROUTER_API_KEY --value '...'
myos tenant-start --tenant demo
myos tenant-status --tenant demo
myos tenant-validate --tenant demo --require-running
```

What to inspect:

- `/srv/tenants/demo/` contains the expected config, state, storage, and secret paths
- `/srv/tenants/<tenant>/home/.config/containers/systemd/openclaw.container` is rendered
- `openclaw.service` is active for the tenant user
- dashboard endpoint responds on the configured loopback port
- stopping either the UI helper or gateway process causes the tenant container to fail rather than silently staying half-alive
- `tenant-validate` passes without missing env, port, or secret failures

If the runtime is intentionally not started yet, at least run:

```bash
myos tenant-validate --tenant demo
```

### Owner-host wrapper changes

On a booted image or host, validate the owner-friendly hosted wrapper against the
fixed dedicated tenant path.

Recommended flow:

```bash
myos openclaw-host enable --user alice --model openrouter/anthropic/claude-sonnet-4-5
myos openclaw-host secret-set --key OPENROUTER_API_KEY --value '...'
myos openclaw-host start
myos openclaw-host status
myos openclaw-host tailscale enable
myos openclaw-host qr
```

What to inspect:

- `myos persistent-user-validate --user alice` reports that the owner role is assigned to `alice`
- tenant user `owner-openclaw` exists and remains a dedicated managed service account
- `/srv/tenants/owner-openclaw/` contains the expected config, state, storage, and secret paths
- `myos openclaw-host status` reports `Owner user: alice` and `Hosted tenant: owner-openclaw`
- `openclaw.service` is active for the `owner-openclaw` tenant user after `myos openclaw-host start`
- `myos openclaw-host tailscale enable` configures host-managed Serve against the hosted tenant loopback port rather than the per-user `openquad` runtime
- `myos openclaw-host qr` produces the pairing QR through the hosted tenant context

If the model secret is not available yet, stop after `secret-set` and record that
runtime validation is still pending.

### Persistent-user runtime changes

On a booted image or host:

```bash
myos persistent-user-enroll --user alice
myos persistent-user-validate --user alice
openquad start
openquad status
openquad update
openquad doctor
```

What to inspect:

- `loginctl show-user alice -p Linger` reports `yes` if persistence is expected
- `~alice/.config/containers/systemd/openclaw.container` exists
- `~alice/.local/share/openclaw/` exists and is writable
- `openclaw.service` is active in Alice's user manager after `openquad start`
- `openquad exec -- openclaw ...` fails clearly when the runtime is inactive instead of auto-starting it

For persistence-specific changes, also test:

- logout/login cycle
- background service survival after logout
- second enrolled user gets a separate per-user instance rather than a shared singleton

### RamaLama CLI changes

Only Alma 10 currently ships the packaged RamaLama CLI.

On an Alma 10 host or image:

```bash
ramalama --help
ramalama list || true
```

What to inspect:

- `ramalama` is present in the image
- the packaged CLI starts successfully
- docs still describe it as an operator utility for local model testing and artifact generation rather than a managed host service

### Workstation Tailscale systray changes

On a booted GNOME image:

```bash
systemctl status tailscaled.service --no-pager
ls -l /etc/xdg/autostart/tailscale-systray.desktop
sudo tailscale set --operator=alice
```

Then log into the GNOME session as `alice` and inspect:

- `tailscaled.service` is still active in **system** scope
- `/etc/xdg/autostart/tailscale-systray.desktop` exists with `Exec=tailscale systray`
- the GNOME session starts `tailscale systray` for the interactive user
- the systray can see and manage the system daemon without converting the daemon into a user service
- `tailscale status` works for the operator user without requiring the daemon itself to move into user scope

If you intentionally leave operator assignment manual, document which account
should receive:

```bash
sudo tailscale set --operator=<username>
```

### Workstation Flatpak changes

On a booted GNOME image:

```bash
flatpak remotes --user
flatpak remotes --system
systemctl cat system-flatpak-setup.service
```

What to inspect:

- user remote exists as `flathub`
- managed system remote exists as `org-system`
- the `system-flatpak-setup.service` drop-in is present if the hide behavior is expected
- interactive `flatpak install/update/remove` defaults to `--user`
- GUI tools primarily surface the user lane rather than two equivalent Flathub catalogs
- system Flatpak mutations still require wheel + authentication

Reference behavior is documented in:

- `files/gnome/flatpak/README.md`

### Alma drift changes

If a change touches `recipes/layers/alma9/**` or `recipes/layers/alma10/**`,
review:

- whether the difference is required by packaging or platform drift
- whether the change should instead live in a shared layer
- whether `docs/alma-drift.md` needs an update

Default policy:

- if the change is not forced by distro drift, prefer the shared layer

## Minimum review checklist for a normal PR

Use this as the default baseline:

- `git diff --check`
- syntax-check every changed shell script
- syntax-check `openclaw-ui-server.mjs` if touched
- JSON-check `openclaw.json.example` if touched
- rerun `scripts/verify-alma9-nvidia-legacy.ps1` if Alma 9 legacy NVIDIA changed
- do at least one runtime validation pass for tenant, persistent-user, or Flatpak behavior if that primary plane changed
- validate RamaLama only when the optional Alma 10 host feature changed or is part of the deployment you care about
- update docs when a path, service name, or intentional Alma 9/10 divergence changed

## When validation is incomplete

Say so explicitly in the PR or review notes.

Examples:

- static checks passed, but no booted image was available
- Alma 10 runtime was checked, but Alma 9 workstation behavior was not
- tenant preflight passed, but no live provider secret was available for a full running validation

The repo is complex enough that partial validation is normal. Hidden validation
scope is worse than incomplete validation declared clearly.
d clearly.
ough that partial validation is normal. Hidden validation
scope is worse than incomplete validation declared clearly.
d clearly.
ssed, but no live provider secret was available for a full running validation

The repo is complex enough that partial validation is normal. Hidden validation
scope is worse than incomplete validation declared clearly.
d clearly.
ough that partial validation is normal. Hidden validation
scope is worse than incomplete validation declared clearly.
d clearly.
ete validation declared clearly.
d clearly.
ete validation declared clearly.
d clearly.
