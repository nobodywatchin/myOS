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

myOS ships the persistent-user baseline and owner buckets empty by default.
That is deliberate.

- The framework exists on every `core-full-*` image and anything built from it.
- Actual baseline or owner services are an image or deployment policy decision.
- If you add baseline units, each enrolled user gets their own separate instance.
- If you need one machine-wide shared singleton, use a system unit instead.

## Session-Bound Desktop Units

The desktop-side OpenClaw helper under `files/agent/quadlets/` remains session-bound.

- `openclaw.container` is tied to `graphical-session.target`.
- `openclaw-watchdog.service` is also tied to `graphical-session.target` and only exists to keep that session unit running while the session is active.
- These units are shipped only through workstation layering now, not the shared `core-full` layer.

That keeps server-oriented full images free from surprise desktop behavior.

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

A user can install and enable their own Quadlet directly, for example:

```bash
cp my-api.container ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user enable --now my-api.service
```

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
- Workstation images still use `/etc/skel` for session-bound desktop conveniences.
- The session-bound OpenClaw watchdog is wired into `graphical-session.target`, not `default.target`.

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
7. On a workstation image, log in graphically and confirm the desktop-side `openclaw.service` starts with the session and stops when the graphical session ends.
8. On any image, confirm `systemctl is-enabled bootc-fetch-apply-updates.timer` reports disabled and that OS updates still stage correctly through `myos update-system`.
9. For the tenant path, run `myos tenant-validate --tenant <name>` to verify the existing dedicated OpenClaw tenant flow still renders Quadlets and uses the persistent/background plane.
