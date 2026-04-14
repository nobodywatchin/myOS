# gnome/shared/

This tree contains the GNOME-only session defaults and helpers.

The workstation-wide Flatpak shell helper, Flatpak service drop-in, and Flatpak
polkit rules now live under `files/workstation/shared/`.

This tree also publishes the GNOME desktop marker at:

- `usr/share/myos/workstation/desktop.env`

The shared workstation display-manager reconciliation helper reads that marker
to decide that a GNOME image should own `gdm.service`.

## Intended Tailscale model

myOS keeps Tailscale split across system and session scopes:

- `tailscaled.service` stays a **system** service
- `tailscale systray` starts in the logged-in **GNOME user session**
- the desktop user controls the system daemon through Tailscale's normal
  operator access model

That means myOS should not convert `tailscaled.service` into a user service, and
it should not try to run the systray at image build time.

## How it works

### 1. The system daemon comes from the shared core layer

`recipes/layers/shared/core.yml`:

- installs the `tailscale` package from the upstream repo
- enables `tailscaled.service` in **system** scope

That keeps the daemon available for both headless and GNOME images.

### 2. GNOME autostarts the systray for each interactive desktop login

`etc/xdg/autostart/tailscale-systray.desktop` starts:

```bash
tailscale systray
```

in the user's GNOME session.

The shared GNOME defaults already enable AppIndicator support, so the systray
has a normal place to surface in GNOME.

### 3. User control is granted to the system daemon explicitly

The systray talks to the already-running system `tailscaled` instance through
Tailscale's local control path. The daemon remains system-scoped; the desktop
session only hosts the UI client.

To let a non-root desktop user manage that system daemon, an admin should set
that login as the Tailscale operator:

```bash
sudo tailscale set --operator=<username>
```

Example:

```bash
sudo tailscale set --operator=noah
```

## Why this is documented instead of auto-detected

This repo does not currently have a generic first-boot or post-install hook that
can reliably identify the intended interactive GNOME user without making
broader assumptions about account creation order, autologin, or ownership.

So the least invasive current policy is:

- ship the system daemon enabled
- ship the GNOME autostart entry for the systray
- document the explicit admin step for operator assignment

If myOS later grows a clearly scoped GNOME workstation first-login provisioning path,
that would be the right place to automate `tailscale set --operator=<username>`.

## Assumptions kept intact

- the existing AppIndicator GNOME extension remains enabled for the systray path
- this change does not alter Tailscale Serve/Funnel host usage for the platform-host tooling

If duplicate Tailscale UI surfaces become a problem, handle that as a separate
follow-up instead of folding it into this autostart patch.
