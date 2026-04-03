# workstation/gnome/

This tree contains the workstation-only GNOME defaults and session helpers.

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

`recipes/layers/shared/core-base.yml`:

- installs the `tailscale` package from the upstream repo
- enables `tailscaled.service` in **system** scope

That keeps the daemon available for both headless and workstation images.

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
can reliably identify the intended interactive workstation user without making
broader assumptions about account creation order, autologin, or ownership.

So the least invasive current policy is:

- ship the system daemon enabled
- ship the GNOME autostart entry for the systray
- document the explicit admin step for operator assignment

If myOS later grows a clearly scoped workstation first-login provisioning path,
that would be the right place to automate `tailscale set --operator=<username>`.

## Assumptions kept intact

- the existing AppIndicator GNOME extension remains enabled for the systray path
- this change does not alter Tailscale Serve/Funnel host usage for the platform-host tooling

If duplicate Tailscale UI surfaces become a problem, handle that as a separate
follow-up instead of folding it into this autostart patch.
