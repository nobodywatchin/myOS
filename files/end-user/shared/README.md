# end-user/shared/

This tree carries end-user runtime and app-governance payloads shared by workstation images.

It owns:

- the shell helper that defaults `flatpak` to user scope
- the system Flatpak visibility drop-in
- the Flatpak export environment file
- the Flatpak polkit rules used by the managed system-vs-user model

This content intentionally lives outside `files/workstation/shared/` because it owns app-governance policy rather than desktop-session behavior.
