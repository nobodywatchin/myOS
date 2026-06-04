# files/

This tree contains payloads copied into images by the BlueBuild `files` module, plus a small number of build helper scripts used by other modules.

## Top-level layout

```text
files/
  base/
  end-user/
  workstation/
  gnome/
  cosmic/
  agent/
  dnf/
  justfiles/
  scripts/
```

## What each tree is for

- `base/`: payload shared by every image.
- `end-user/`: shared Flatpak governance and end-user runtime payloads for workstation images.
- `workstation/`: shared DE-agnostic workstation payloads.
- `gnome/`: GNOME family payloads.
- `cosmic/`: COSMIC family payloads.
- `agent/runtime-core/`: shared cross-image runtime helpers plus ROCm/AMD payloads that belong to the shared core contract.
- `agent/nvidia/`: NVIDIA-only profile and systemd payloads copied by `shared/nvidia-base.yml`.
- `agent/platform-host/`: shared host payloads such as tenant tooling, persistent-user tooling, and `openclaw-host`.
- `dnf/`: repository files used by `dnf` modules.
- `justfiles/`: shared just recipes copied into the image.
- `scripts/`: build helper scripts used by non-files BlueBuild modules.

## Important split

The refactor deliberately split the old platform-host payload into two contracts.

- `agent/runtime-core/` is safe to ship on every image.
- `agent/nvidia/` is NVIDIA-image only.
- `agent/platform-host/` is server/admin only.

That split keeps shared runtime capabilities available on every image without implying that every image is a hosted OpenClaw appliance.
