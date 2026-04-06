# files/

This tree contains payloads copied into images by the BlueBuild `files` module.

If you are coming from a BlueBuild background, read this as:

- the `recipes/layers/**.yml` files decide **when** payloads are included
- the `files/**` tree defines **what** gets copied into the image

## Top-level layout

```text
files/
  base/
  workstation/
  agent/
  dnf/
  justfiles/
  scripts/
```

## What each tree is for

### `base/`

Shared payload for all core images.

Current usage in this repo is intentionally small:

- `base/runtime/` for shared runtime defaults
- `base/branding/` for late branding assets

### `workstation/`

Shared workstation payloads layered by `shared/workstation-base.yml`.

- `workstation/gnome/` for GNOME-session and desktop defaults
- `workstation/flatpak/` for Flatpak UX helpers, policy, and the managed-vs-user Flatpak model (`workstation/flatpak/README.md`)

### `agent/`

Host-side OpenClaw/myOS platform payloads.

This is the biggest payload tree because it carries the packaged host tooling and templates used by the shared full-core substrate.

- `agent/platform-host/etc/` -> copied to `/etc`
- `agent/platform-host/usr/` -> copied to `/usr`
- `agent/platform-host/var/` -> copied to `/var`
- `agent/nvidia/etc/` -> NVIDIA-only shell and ldconfig payloads used by `shared/nvidia-cuda.yml`
- `agent/justfiles/` -> shared `myos` just command surface layered into full-core/workstation images

### `dnf/`

Repository files used by the BlueBuild `dnf` module.

### `justfiles/`

Shared just recipes copied into the image.

### `scripts/`

Standalone helper scripts used by layer-specific modules.

## Why some content lives under `var/srv/...`

BlueBuild's `files` module is straightforward, but it has an important caveat: do not copy payload directly into paths that become symlinks on atomic systems.

That matters for `/srv`.

In this repo, persistent tenant and model content is staged under:

- `files/agent/platform-host/var/srv/...`

and then copied into `/var`, which yields runtime paths under `/var/srv/...` without fighting the atomic filesystem layout.

So if you are looking for tenant or model skeleton content and expect a direct `files/.../srv/...` tree, that absence is intentional.

## How to trace a payload

1. find the `files` module entry in a layer file
2. note the `source:` and `destination:`
3. map that back to `files/<source>/...`
4. read the destination as the final image path after copy

Example:

```yaml
- type: files
  files:
    - source: workstation/gnome
      destination: /
```

means:

- take `files/workstation/gnome/**`
- copy it into the image root
- so nested paths inside that tree become their normal runtime locations
