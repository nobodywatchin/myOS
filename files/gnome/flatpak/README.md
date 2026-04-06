# gnome/flatpak/

This tree contains the GNOME-only Flatpak UX and policy layer.

It does **not** replace BlueBuild's `default-flatpaks` module.
Instead, it shapes how the GNOME images use the remotes and apps that
BlueBuild creates at boot.

## Intended model

GNOME images intentionally expose two Flatpak lanes:

- `flathub` in **user** scope for normal personal installs
- `org-system` in **system** scope for curated, image-managed shared apps

The goal is:

- user installs stay in the user's home by default
- curated shared apps can still be installed system-wide
- users do not browse two fully visible Flathub catalogs
- admins can still deliberately manage system Flatpaks

## How it works

### 1. BlueBuild creates and manages the remotes/apps

`recipes/layers/shared/gnome-base.yml` uses `default-flatpaks` with:

- one `scope: user` Flathub remote named `flathub`
- one `scope: system` Flathub remote named `org-system`
- a curated install list for `org-system`

BlueBuild's upstream `system-flatpak-setup.service` creates/enables the system
remote and installs the configured system apps.

### 2. Interactive CLI use defaults to user scope

`etc/profile.d/flatpak-user-default.sh` wraps `flatpak` in interactive shells so
common verbs such as `install`, `remove`, and `update` default to `--user`
unless the caller explicitly passes `--system`.

This is a UX guardrail, not a hard security boundary.

### 3. The managed system remote is re-hidden after setup

`etc/systemd/system/system-flatpak-setup.service.d/10-hide-org-system.conf`
adds an `ExecStartPost=` hook to BlueBuild's
`system-flatpak-setup.service`.

That post-step re-applies:

- `--no-enumerate`
- `--no-use-for-deps`

for the `org-system` remote.

This keeps the managed system remote out of normal application enumeration while
still letting BlueBuild use it explicitly during setup.

Important:

- this is intentionally a **drop-in on BlueBuild's service**, not a separate
  oneshot service
- tying the hide step to `system-flatpak-setup.service` avoids races where the
  remote did not exist yet when a standalone hide service ran
- there is no stamp file on purpose; the hide step is safe to reapply every
  time the upstream setup service runs

### 4. Polkit keeps system Flatpak changes admin-only

`usr/share/polkit-1/rules.d/org.freedesktop.Flatpak.rules` enforces:

- only `wheel` can perform system-level Flatpak changes
- those changes require authentication
- local active users may still refresh metadata/appstream for GUI visibility

So the real permission boundary is polkit, not remote visibility.

## What users should experience

### Normal user

- GUI tools should primarily surface the user Flathub lane
- interactive `flatpak install/update/remove` should default to `--user`
- system-wide Flatpak mutations should not succeed without admin privileges

### Admin

- can still explicitly use `flatpak --system ...`
- can still manage the `org-system` remote deliberately
- can still install/update/remove curated system Flatpaks with authentication

## Maintenance notes

- If BlueBuild renames or replaces `system-flatpak-setup.service`, update the
  drop-in path here.
- Do not reintroduce a standalone `flatpak-hide-org-system.service` unless you
  also prove its ordering against BlueBuild's boot-time Flatpak setup.
- If the managed system remote ever needs to become stricter than “hidden from
  enumeration”, consider a Flatpak remote filter as a separate design change.
