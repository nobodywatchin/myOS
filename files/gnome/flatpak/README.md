# gnome/flatpak/

The shared Flatpak shell helper, service drop-in, and polkit rules moved to
`files/workstation/shared/` so GNOME and COSMIC images can use the same
workstation-wide policy.

GNOME-specific Flatpak app choices still live in the GNOME recipe layers.
