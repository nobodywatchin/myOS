# Rootless Persistence Model

## Two Planes

myOS now treats rootless Podman and Quadlet workloads as two separate planes.

- Persistent or background plane: systemd user services that are expected to survive logout, user switching, and idle session teardown. These require lingering.
- Desktop or session plane: user services that should follow the graphical session and stop when the session ends.

The split is intentional. A GUI helper should not silently become an always-on
background daemon just because it happens to use Podman.

## Dedicated Tenants Versus Login Users

The existing tenant framework stays in place as the dedicated app-hosting path.

- `myos tenant-*` manages dedicated service accounts.
- Each tenant is a separate user under `/srv/tenants/<tenant>/home` with rootless storage under `/var/tmp/myos-podman/<tenant>/storage`.
- Tenant Quadlets are rendered from `/etc/myos/templates/apps/openclaw/` into that managed account and enabled against `default.target`.

That is different from login-user persistence.

- `myos persistent-user-*` manages existing login users.
- Enrolled users keep using their real home directories and their own user systemd manager.
- Admin-managed baseline and owner-only templates are copied into `~/.config/containers/systemd/` and tracked through `/etc/myos/persistent-users/`.

## Template Layout

The template tree is now explicit.

- `/etc/myos/templates/apps/openclaw/`: dedicated tenant-account OpenClaw hosting plus the shipped self-service per-user `openclaw.container` template under `user/`.
- `/etc/myos/templates/persistent-users/baseline/quadlets/`: per-user baseline rootless services for every enrolled user.
- `/etc/myos/templates/persistent-users/owner/quadlets/`: rootless services that belong only to the selected owner.

The key boundary is that the per-user OpenClaw runtime is **not** part of the
persistent-user baseline bucket.

- The framework exists on every `core-full-*` image and anything built from it.
- Baseline and owner buckets are for admin-managed per-user services that enrollment reconciles into `~/.config/containers/systemd/`.
- The per-user OpenClaw runtime ships separately under `/etc/myos/templates/apps/openclaw/user/` and is installed on demand by `openquad`, not by enrollment.
- If you add more baseline units, each enrolled user gets their own separate instance.
- If you need one machine-wide shared singleton, use a system unit instead.

## Per-User OpenClaw Runtime

OpenClaw now follows the persistent-user plane instead of the old desktop
session plane.

- `openquad` is the host-side runtime control plane. It owns `start`, `stop`, `restart`, `update`, `status`, `logs`, `doctor`, `inspect`, `exec`, `shell`, and `version`.
- The per-user runtime is shipped as `openclaw.container` under `/etc/myos/templates/apps/openclaw/user/`.
- `openquad start` renders that shipped Quadlet into `~/.config/containers/systemd/` on demand for the current user and starts the generated `openclaw.service`. For Quadlets, the generator applies the install metadata during generation, so operators should think in terms of rendering and starting or restarting the generated service rather than manually enabling a separate unit file.
- `openquad exec -- ...` runs commands inside the already-running runtime container, and `openquad shell` opens an interactive shell there.
- Lingering, subuid/subgid provisioning, and admin-managed template reconciliation still come from `myos persistent-user-enroll`, but enrollment no longer installs the per-user OpenClaw runtime by default.
- The container stays rootless, per-user, and quadlet-backed.

The boundary is intentional.

- `openquad` owns host-side lifecycle and entry.
- The upstream `openclaw` CLI lives inside the runtime container.
- If the runtime is missing or inactive, users should fix it with `openquad` rather than expecting a host wrapper to auto-start it.

## Admin Enrollment Flow

Enroll an existing login user for persistent hosting:

```bash
myos persistent-user-enroll --user alice
```

Assign or transfer the owner-only role:

```bash
myos persistent-user-set-owner --user alice
```

Validate the resulting setup:

```bash
myos persistent-user-validate --user alice
```

Remove admin-managed persistent-user units and optionally lingering:

```bash
myos persistent-user-remove --user alice --disable-linger
```

What enrollment does:

- enables lingering for that user
- ensures the user has `subuid` and `subgid` ranges for rootless Podman
- installs any admin-managed baseline template bucket entries into that user's `~/.config/containers/systemd/`
- installs the owner-only bucket as well if that user is the selected owner
- reloads the user's systemd manager and enables any service-capable units that came from those managed buckets
- records the managed files and units under `/etc/myos/persistent-users/`

## Owner-Hosted OpenClaw Wrapper

For remote device pairing, Tailscale Serve, and a stable hosted dashboard, myOS
now exposes an owner-friendly wrapper over the dedicated tenant path:

```bash
myos openclaw-host enable --user alice
myos openclaw-host secret-set --key OPENROUTER_API_KEY
myos openclaw-host start
myos openclaw-host tailscale enable
myos openclaw-host qr
```

That wrapper is intentionally not a third runtime plane. It is the supported
single-host preset over the tenant system.

- It records the selected login user through the existing persistent-user owner role.
- It provisions and manages a fixed dedicated tenant service account for the hosted gateway.
- It keeps the hosted runtime on the same tenant state/workspace/secrets split as the broader tenant system rather than introducing a separate special-case layout.
- It reuses the tenant-side localhost port publication, host-managed Tailscale Serve integration, pairing URL wiring, and the supervised single-container tenant startup path.
- It does not change the per-user `openquad` contract or expose the per-user runtime directly.

Use this wrapper when you want a machine's primary remotely reachable OpenClaw
service to stay easy to pair and easy to expose over Tailscale. Use the normal
`openquad` workflow when you want a login user's own separate local per-user
runtime.

Quick smoke test:

```bash
myos openclaw-host enable --user alice --model openrouter/anthropic/claude-sonnet-4-5
myos openclaw-host secret-set --key OPENROUTER_API_KEY
myos openclaw-host start
myos openclaw-host status
myos openclaw-host tailscale enable
myos openclaw-host qr
```

## User Self-Service Persistent Quadlets

The supported self-service location is the standard rootless Quadlet path:

- `~/.config/containers/systemd/`

A user can install and start their own Quadlet directly, for example:

```bash
cp my-api.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start my-api.service
```

For Quadlets, the generator applies the `[Install]` section during generation, so the generated `.service` should be started or restarted directly instead of being enabled with `systemctl enable`.

myOS also ships a small helper:

```bash
myos persistent-user-install-quadlet --file ./my-api.container --enable
```

Persistence is guaranteed only when both of these are true:

- the workload is managed by systemd user units
- the user has lingering enabled

Raw `podman run -d` launched from an interactive shell is not part of the
persistence guarantee unless the container is converted into a managed user
service or Quadlet.

## /etc/skel Policy

`/etc/skel` is no longer used to opt every new user into persistent hosting.

- Persistent hosting is an explicit admin action through `myos persistent-user-enroll`.
- GNOME images can still use `/etc/skel` for desktop conveniences, but the OpenClaw runtime is no longer injected there.
- Enrollment may reconcile admin-managed baseline or owner templates for opted-in users, but the per-user OpenClaw runtime is separate from those buckets.
- The OpenClaw runtime instead comes from the shipped `apps/openclaw/user` template and is installed on demand by `openquad`.

## OpenClaw Workflow

Local per-user runtime setup:

```bash
myos persistent-user-enroll --user alice
```

Remote-friendly hosted setup:

```bash
myos openclaw-host enable --user alice
```

User workflow:

```bash
openquad start
openquad exec -- openclaw onboard
openquad exec -- openclaw chat
```

Useful runtime commands:

```bash
openquad status
openquad doctor
openquad logs
openquad shell
openquad exec -- openclaw run file.md
```

## bootc Update Policy

myOS disables the stock `bootc-fetch-apply-updates.service` and
`bootc-fetch-apply-updates.timer` in the shared base layer.

That means:

- the host will not auto-apply a new image and surprise-reboot on its own
- `myos update-system` still wraps `sudo bootc upgrade`
- `myos rebase` still wraps `sudo bootc switch`
- reboot timing stays an explicit operator choice or a planned maintenance-window action

## Manual Verification Plan

1. Enroll one user as a normal persistent host with `myos persistent-user-enroll --user alice`.
2. If you want to exercise owner-only templates, assign the owner role with `myos persistent-user-set-owner --user alice`.
3. Drop a simple test Quadlet into `/etc/myos/templates/persistent-users/baseline/quadlets/`, re-run enrollment for `alice`, and confirm `systemctl --user status <unit>` stays active after `alice` logs out.
4. Log in as another user and confirm the `alice` background unit is still running.
5. Enroll a second user and confirm the baseline service becomes a separate per-user instance rather than a shared singleton.
6. Confirm a non-enrolled user does not have lingering enabled and does not receive the admin-managed baseline Quadlet files.
7. On an enrolled user account, run `openquad start`, confirm `systemctl --user status openclaw.service` is active, then verify `openquad exec -- openclaw chat` works against the running runtime without changing its lifecycle implicitly.
8. On any image, confirm `systemctl is-enabled bootc-fetch-apply-updates.timer` reports disabled and that OS updates still stage correctly through `myos update-system`.
9. For the tenant path, run `myos tenant-validate --tenant <name>` to verify the existing dedicated OpenClaw tenant flow still renders Quadlets and uses the persistent/background plane.
10. For the owner-host wrapper, run `myos openclaw-host enable --user alice`, then confirm `myos openclaw-host status` reports the fixed hosted tenant and that `myos openclaw-host tailscale status` proxies through to the tenant Tailscale state.
 Tailscale state.
