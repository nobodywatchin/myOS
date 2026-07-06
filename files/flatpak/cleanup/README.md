# flatpak/cleanup/

This tree carries the shared system Flatpak maintenance helper used by image startup hooks and `current` Justfile targets.

The helper only operates on the system Flatpak installation. User Flatpak installs are never cleaned or repaired unless a user runs Flatpak commands for their own user scope.
