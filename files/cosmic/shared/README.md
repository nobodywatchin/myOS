# cosmic/shared/

This tree contains COSMIC-family workstation payloads.

It owns COSMIC-specific greeter and session behavior, COSMIC portal selection, plus the family marker at `usr/share/myos/workstation/desktop.env` consumed by the shared workstation display-manager helper.

Keep COSMIC-only session glue here instead of mixing it into `files/workstation/shared/`.

COSMIC prefers the packaged `cosmic-greeter.service` path when it is present.
The shared workstation helper repairs that service ownership at boot and keeps the
`cosmic-greeter` PAM stack aligned for keyring unlock support.

The shipped `cosmic-portals.conf` follows COSMIC upstream preference order: `cosmic;gtk` with `gnome-keyring` for the Secret portal.
