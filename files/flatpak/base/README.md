# flatpak/base/

This tree carries workstation Flatpak policy and session payloads.

It owns:

- the shell helper that defaults `flatpak` to user scope
- the system Flatpak visibility drop-in for the managed `org-system` remote
- Flatpak export environment defaults
- the image-provided session hook that imports graphical environment into D-Bus and `systemd --user`
- the Flatpak polkit rules used by the managed system-vs-user model

Cleanup and repair helpers live under `files/flatpak/cleanup/` and are included by `recipes/layers/shared/flatpak-cleanup.yml`.
