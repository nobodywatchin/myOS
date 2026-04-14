# gnome/shared/

This tree contains GNOME-family workstation payloads.

It owns GNOME-specific session behavior, GNOME-only helpers, and the family marker at `usr/share/myos/workstation/desktop.env` consumed by the shared workstation display-manager helper.

The shared Flatpak governance payloads no longer live here or under `workstation/shared/`; they live under `files/end-user/shared/` so they can also be reused by Console.

Tailscale remains split intentionally:

- `tailscaled.service` stays in the shared core system scope
- `tailscale systray` starts in the logged-in GNOME session
