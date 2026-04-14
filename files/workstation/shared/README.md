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

This tree carries the workstation-wide shell helper, Flatpak service drop-in,
polkit rules, and the boot-time display-manager reconciliation helper.

## Display-manager reconciliation

Workstation images now ship a shared oneshot unit and helper script that run on
every boot before the display manager:

- `usr/lib/systemd/system/myos-workstation-dm-apply.service`
- `usr/libexec/myos-workstation-dm-apply`

That helper reads the active desktop marker from
`/usr/share/myos/workstation/desktop.env` and then repairs stale
`display-manager.service` state left behind by bootc/rpm-ostree rebases.

The shared workstation tree owns the helper because the behavior is the same
for every workstation image. The desktop-specific marker stays with the
desktop-specific payload tree.

GNOME-only session helpers and GNOME-specific autostart behavior stay under
`files/gnome/shared/`.
