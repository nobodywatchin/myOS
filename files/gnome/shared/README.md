# gnome/shared/

This tree contains GNOME-family workstation payloads.

It owns GNOME-specific session behavior, GNOME portal selection, GNOME-only helpers, and the family marker at `usr/share/myos/workstation/desktop.env` consumed by the shared workstation display-manager helper.

The shared Flatpak governance payloads live under `files/flatpak/base/`, which keeps app policy separate from GNOME session behavior.

Tailscale remains split intentionally:

- `tailscaled.service` stays in the shared core system scope
- `tailscale systray` starts in the logged-in GNOME session
