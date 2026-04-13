# Workstation Layering Plan

This note records the workstation structure, the COSMIC image addition, and the
layering boundaries used by this refactor.

## Pre-Refactor Summary

- Published image entrypoints live under `recipes/images/**`.
- Shared composition units live under `recipes/layers/**`.
- Before this refactor, the workstation products were only the `gnome-*`
  images.
- `gnome-*` images build from published `core-full-*` images instead of from the
  AlmaLinux BootC base directly.
- `recipes/layers/shared/gnome-base.yml` currently mixes:
  - shared workstation packages and Flatpak policy
  - GNOME session packages and GNOME payloads
  - workstation diagnostics/admin tooling
- GNOME distro drift lives in `recipes/layers/alma9/gnome.yml` and
  `recipes/layers/alma10/gnome.yml`.
- NVIDIA workstation extras currently live in `recipes/layers/shared/nvidia-gnome.yml`,
  but the content is workstation-display oriented rather than GNOME-specific.

## Proposed Image Names

- `cosmic-alma9`
- `cosmic-alma9-nvidia-open`
- `cosmic-alma9-nvidia-legacy`
- `cosmic-alma10`
- `cosmic-alma10-nvidia-open`

GNOME images stay intact:

- `gnome-alma9`
- `gnome-alma9-nvidia-open`
- `gnome-alma9-nvidia-legacy`
- `gnome-alma10`
- `gnome-alma10-nvidia-open`

## Layering Model

- `workstation-common`
  - DE-agnostic workstation packages
  - shared multimedia/session tooling
  - shared Flatpak policy and shell helpers
  - shared workstation diagnostics/admin utilities
  - shared desktop-only extras such as Homebrew support
- `alma9/workstation.yml` and `alma10/workstation.yml`
  - distro-specific workstation drift that should be shared by GNOME, COSMIC,
    and future KDE images
- `workstation-gnome`
  - GNOME session packages
  - GNOME Software and GNOME-specific Flatpak/app wiring
  - GNOME dconf payloads and GNOME-only session helpers
  - GNOME-only extensions and GNOME-specific packaging drift
- `workstation-cosmic`
  - version-aware `ligenix/enterprise-cosmic` COPR enablement
  - COSMIC desktop package install
  - COSMIC greeter/session enablement
  - COSMIC-specific portal/session integration
- `nvidia-workstation`
  - workstation-display-oriented NVIDIA extras shared by GNOME and COSMIC

## Files To Add

- `recipes/layers/shared/workstation-common.yml`
- `recipes/layers/shared/workstation-gnome.yml`
- `recipes/layers/shared/workstation-cosmic.yml`
- `recipes/layers/shared/nvidia-workstation.yml`
- `recipes/layers/alma9/workstation.yml`
- `recipes/layers/alma10/workstation.yml`
- `recipes/images/cosmic/alma9/*.yml`
- `recipes/images/cosmic/alma10/*.yml`
- `files/workstation/shared/**`

## Files To Modify

- `recipes/images/gnome/**`
  - move GNOME images onto `workstation-common` + `workstation-gnome`
- `recipes/layers/shared/gnome-base.yml`
- `recipes/layers/shared/nvidia-gnome.yml`
  - keep thin compatibility wrappers while the new workstation layer names
    become the documented first-class path
- `recipes/layers/alma9/gnome.yml`
- `recipes/layers/alma10/gnome.yml`
  - keep only real Alma-specific GNOME drift
- `.github/workflows/build.yml`
  - add COSMIC build matrix entries
- `files/justfiles/usr/share/myos/just/rebase.just`
  - expose new COSMIC image names
- `README.md`
- `recipes/README.md`
- `recipes/layers/README.md`
- `files/README.md`
- `docs/image-architecture.md`
- `docs/validation.md`
- `docs/alma-drift.md`
- `docs/rootless-persistence.md`
  - update workstation-family terminology and layering docs

## Shared vs Desktop-Specific

Move into `workstation-common`:

- Flatpak runtime/policy wiring
- PipeWire/WirePlumber and general multimedia/session packages
- DE-agnostic workstation hardware/network/printing/scanning packages
- common workstation diagnostics/admin tools
- workstation-wide user shell helpers

Keep GNOME-specific:

- `gdm`
- `gnome-*` session packages
- `xdg-desktop-portal-gnome`
- GNOME dconf payloads
- GNOME Software cleanup and GNOME Flatpak app choices
- GNOME extensions

Keep COSMIC-specific:

- `ligenix/enterprise-cosmic` COPR enablement
- COSMIC desktop bundle selection
- `cosmic-greeter` / greetd stack
- `xdg-desktop-portal-cosmic`

## Risks And Unknowns

- The COPR result indexes confirm EL9 and EL10 package lanes plus
  `cosmic-greeter`, `greetd`, `xdg-desktop-portal-cosmic`, and `cosmic-epoch`.
- The COPR install example references `cosmic-desktop`, but I could not do a
  live DNF resolution in this environment because `dnf` is not installed here.
- The implementation therefore probes for `cosmic-desktop` at build time and
  falls back to the confirmed `cosmic-epoch` bundle package if the COPR only
  exposes that name.
- `cosmic-greeter.service` is assumed to be the right enablement target because
  that matches the COPR installation guidance; if the built image exposes a
  different unit shape, the follow-up should stay narrowly scoped to the COSMIC
  layer instead of weakening other workstation images.
- No booted GNOME or COSMIC image is available in this environment, so runtime
  validation here is limited to repo wiring and static consistency checks.
