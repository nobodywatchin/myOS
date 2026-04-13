# recipes/

If you already think in BlueBuild terms, start here.

## Mental model

- `recipes/images/` contains the published image entrypoints.
- `recipes/layers/` contains the reusable composition units those images pull in
  with `from-file:`.

The image recipes stay intentionally small:

- choose a `base-image`
- set the image name and description
- include shared and distro-specific layer files in order
- finish with `initramfs` and `signing`

## Image families

```text
images/
  core/
    alma9/
    alma10/
  gnome/
    alma9/
    alma10/
  cosmic/
    alma9/
    alma10/
```

### Core images

`core-full-*` is the single feature-complete core tier.

These recipes build directly from the AlmaLinux BootC base image and then
compose:

- `layers/shared/full.yml`
- one distro-specific core delta
- optional NVIDIA stream layers

### Workstation images

GNOME and COSMIC images both build from the published `core-full-*` images, not
directly from the AlmaLinux BootC base image.

That means workstation recipes should read like thin additive layers:

- `layers/shared/workstation-common.yml`
- one distro-specific workstation delta
- one DE-specific workstation layer
- optional DE-specific distro drift
- optional workstation NVIDIA extras

Current workstation families are:

- GNOME: `workstation-common` + `alma*/workstation` + `workstation-gnome` +
  `alma*/gnome`
- COSMIC: `workstation-common` + `alma*/workstation` + `workstation-cosmic`

Thin compatibility wrappers remain at `layers/shared/gnome-base.yml` and
`layers/shared/nvidia-gnome.yml`, but new work should target the explicit
workstation layer names.

## Layer responsibilities

Use `recipes/layers/README.md` as the quick map for:

- what each shared layer owns
- where Alma 9 and Alma 10 are expected to diverge
- where optional features belong

## When adding or changing something

### If it is shared across all core images

Start in one of:

- `layers/shared/core.yml`
- `layers/shared/full.yml`

### If it is shared across all workstation images

Start in:

- `layers/shared/workstation-common.yml`

### If it is distro-specific workstation behavior

Start in one of:

- `layers/alma9/workstation.yml`
- `layers/alma10/workstation.yml`

### If it is shared GNOME desktop behavior

Start in:

- `layers/shared/workstation-gnome.yml`

### If it is shared COSMIC desktop behavior

Start in:

- `layers/shared/workstation-cosmic.yml`

### If it is distro-specific GNOME behavior

Start in one of:

- `layers/alma9/gnome.yml`
- `layers/alma10/gnome.yml`

### If it is optional and should not silently grow every image

Put it in:

- `layers/features/`

## BlueBuild-native reading order

For a quick repo read:

1. open the target image under `recipes/images/**`
2. follow each `from-file:` in order
3. check `files/README.md` when a `files` module pulls in payload trees
4. check `modules/os-release-meta/` for the local EL metadata module
