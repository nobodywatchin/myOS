# end-user/shared/

This tree carries end-user runtime and app-governance payloads shared by Workstation and Console.

It owns:

- the shell helper that defaults `flatpak` to user scope
- the system Flatpak visibility drop-in
- the Flatpak export environment file
- the Flatpak polkit rules used by the managed system-vs-user model

This content intentionally moved out of `files/workstation/shared/` so Console can share the same app/runtime policy without pretending Console is just a workstation variant.
