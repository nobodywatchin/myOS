# workstation/shared/

This tree contains workstation-wide payloads shared by GNOME and COSMIC images.

## Intended model

Workstation images intentionally expose two Flatpak lanes:

- `flathub` in **user** scope for normal personal installs
- `org-system` in **system** scope for curated, image-managed shared apps

The goal is:

- user installs stay in the user's home by default
- curated shared apps can still be installed system-wide
- users do not browse two fully visible Flathub catalogs
- admins can still deliberately manage system Flatpaks

This tree only carries the workstation-wide shell helper, Flatpak service
drop-in, and polkit rules for that shared model.

GNOME-only session helpers and GNOME-specific autostart behavior stay under
`files/gnome/shared/`.
