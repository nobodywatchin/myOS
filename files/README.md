# files/

This tree contains payloads copied into images by the BlueBuild `files` module.

## Top-level layout

```text
files/
  base/
  end-user/
  workstation/
  gnome/
  cosmic/
  console/
  agent/
  dnf/
  justfiles/
  scripts/
```

## What each tree is for

- `base/`: payload shared by every image.
- `end-user/`: shared Flatpak governance and end-user runtime payloads for Workstation and Console.
- `workstation/`: shared DE-agnostic workstation payloads.
- `gnome/`: GNOME family payloads.
- `cosmic/`: COSMIC family payloads.
- `console/`: Console preview payloads.
- `agent/runtime-core/`: per-user OpenClaw runtime helpers and shared ROCm runtime files that now belong to core.
- `agent/platform-host/`: full-tier host/operator payloads such as tenant tooling, persistent-user tooling, and `openclaw-host`.
- `dnf/`: repository files used by `dnf` modules.
- `justfiles/`: shared just recipes copied into the image.

## Important split

The refactor deliberately split the old platform-host payload into two contracts.

- `agent/runtime-core/` is safe to ship on every image.
- `agent/platform-host/` is full-tier only.

That is how myOS keeps optional per-user OpenClaw support everywhere without implying that every image is a hosted OpenClaw appliance.
