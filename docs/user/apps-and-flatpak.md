# Apps And Flatpak

Current keeps two Flatpak lanes on workstation images.

## User-managed apps

`flathub` is available in user scope for normal personal app installs.

That means the default path for a user-installed app is still the user's own home directory and user session.

## Admin-managed apps

`org-system` is the image-managed system scope for curated shared apps.

It is hidden from app and source enumeration, but Flatpak can still use it for automatic runtime dependency resolution for managed system apps.

This is where the image or an admin can keep a clean shared app set without turning every machine into an anything-goes system-wide app bucket.

## Startup behavior

Workstation sessions import `DISPLAY`, `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP`, `XDG_DATA_DIRS`, and `PATH` into D-Bus activation and `systemd --user` early in the graphical login.

That keeps portal backends and D-Bus activated Flatpak helpers aligned with the real desktop session instead of inheriting a stale or incomplete environment.

## Maintenance helpers

System-scope maintenance never touches user Flatpak installs.

Useful targets:

- `current flatpak-status` shows system remotes, apps, runtimes, and extensions.
- `current flatpak-clean-system` removes unused system-scope Flatpak runtime content.
- `current flatpak-repair-system` runs system-scope Flatpak repair and reapplies the system baseline.
- `current flatpak-portal-status` shows the current user's portal service state.

`current update-system` updates system Flatpaks, safely cleans unused system runtime content, reapplies the baseline extension warmup, then stages the bootc image update.

Legacy `myos` commands remain compatibility aliases.

## Why this split exists

The split is there so both of these can be true at once:

- users keep ownership of their own app installs
- admins still get a real, deliberate place for shared curated apps

That is why Current keeps the system-vs-user Flatpak model instead of flattening everything into one scope.
