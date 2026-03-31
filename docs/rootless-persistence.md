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

- `/etc/myos/templates/apps/openclaw/`: dedicated tenant-account OpenClaw hosting.
- `/etc/myos/templates/persistent-users/baseline/quadlets/`: per-user baseline rootless services for every enrolled user.
- `/etc/myos/templates/persistent-users/owner/quadlets/`: rootless services that belong only to the selected owner.

The OpenClaw runtime now lives in the baseline bucket so every enrolled user
gets their own separate instance.

- The framework exists on every `core-full-*` image and anything built from it.
- If you add more baseline units, each enrolled user gets their own separate instance.
- If you need one machine-wide shared singleton, use a system unit instead.

## Per-User OpenClaw Runtime

OpenClaw now follows the persistent-user plane instead of the old desktop
session plane.

- `openclaw` is the thin host-side workload CLI. It only execs into the already-running per-user container.
- `openquad` is the runtime control plane. It owns `start`, `stop`, `restart`, `status`, `logs`, `doctor`, `inspect`, and `version`.
- The per-user runtime is shipped as `openclaw.container` under `/etc/myos/templates/persistent-users/baseline/quadlets/`.
- Enrollment copies that Quadlet into `~/.config/containers/systemd/` and enables `openclaw.service` against `default.target`.
- On upgraded accounts that predate this rollout, `openquad start` will render that shipped baseline Quadlet into `~/.config/containers/systemd/` if it is missing.
- Lingering, subuid/subgid provisioning, and admin-managed template reconciliation still come from `myos persistent-user-enroll`.
- The container stays rootless, per-user, and quadlet-backed.

The wrapper boundary is intentional.

- `openclaw` does not auto-start the runtime.
- `openclaw` does not manage service lifecycle.
- If the runtime is missing or inactive, `openclaw` sends the user to `openquad`.

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
- installs the baseline template bucket into that user's `~/.config/containers/systemd/`
- installs the owner-only bucket as well if that user is the selected owner
- reloads the user's systemd manager and enables any service-capable units that came from those managed buckets
- records the managed files and units under `/etc/myos/persistent-users/`

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
- Workstation images can still use `/etc/skel` for desktop conveniences, but the OpenClaw runtime is no longer injected there.
- The OpenClaw runtime now comes from the persistent-user baseline template bucket and is tied to `default.target`.

## OpenClaw Workflow

Admin setup:

```bash
myos persistent-user-enroll --user alice
```

User workflow:

```bash
openquad start
openclaw chat
```

Useful runtime commands:

```bash
openquad status
openquad doctor
openquad logs
openclaw run file.md
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
7. On an enrolled user account, run `openquad start`, confirm `systemctl --user status openclaw.service` is active, then verify `openclaw chat` runs without starting the runtime implicitly.
8. On any image, confirm `systemctl is-enabled bootc-fetch-apply-updates.timer` reports disabled and that OS updates still stage correctly through `myos update-system`.
9. For the tenant path, run `myos tenant-validate --tenant <name>` to verify the existing dedicated OpenClaw tenant flow still renders Quadlets and uses the persistent/background plane.
