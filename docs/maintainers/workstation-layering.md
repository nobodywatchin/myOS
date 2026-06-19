# Workstation Layering

Workstation is the operator desktop and laptop role. GNOME and COSMIC are implementations of that role.

## Layer order

All workstation recipes build in this order:

1. distro core stack
2. `layers/shared/flatpak-base.yml`
3. `layers/shared/workstation-common.yml`
4. distro workstation drift
5. environment layer
6. optional workstation NVIDIA layer when applicable

Alma 10 and Fedora add one more shared layer in the middle:

- `layers/shared/workstation-modern.yml` after `workstation-common`
- `layers/shared/workstation-gnome-modern.yml` for GNOME images after `workstation-gnome.yml`

## Flatpak layering

Flatpak ownership is split from session ownership:

- `flatpak-base` owns Flatpak packages, user `flathub`, hidden admin-managed `org-system`, shared managed apps, policy payloads, cleanup/repair helper inclusion, and the graphical session environment import hook.
- `flatpak-gnome` owns GNOME portal backend packages, explicit GNOME portal selection, and GNOME-specific system Flatpaks.
- `flatpak-gnome-legacy` owns only the Alma 9 GNOME Flatpak app delta for apps that are native RPMs on modern GNOME lanes.
- `flatpak-cosmic` owns COSMIC portal backend packages, explicit COSMIC portal selection, and COSMIC Flatpak remotes.

Server images do not consume these layers and should not receive desktop portal backends or session Flatpak hooks.

The system Flatpak policy is intentionally opinionated. It keeps managed shared apps separate from user-owned `flathub` installs so multi-user machines do not drift into sharing the wrong application state.

## Workstation common orchestration

`workstation-common.yml` should stay small. It is an orchestrator, not a dumping ground.

It includes:

- `workstation-substrate.yml`: shared desktop, hardware, input, audio, printing, scanning, camera, language, and base workstation package substrate
- `workstation-admin-tools.yml`: workstation-only diagnostics, storage, network, and admin utilities
- `workstation-policy.yml`: graphical target, display-manager reconciliation, and workstation sleep policy
- `workstation-user-tools.yml`: opinionated user-facing workstation tooling such as Homebrew and Brave Origin Beta

This prevents GNOME and COSMIC from duplicating the same substrate while keeping workstation product opinions visible and reviewable.

## Brave Origin Beta

Brave Origin Beta is intentionally shipped in workstation images from the RPM repository because it is not available through Flathub.

That is a product opinion, not an accidental dependency. Keep it in `workstation-user-tools.yml` so the opinion stays explicit.

## GNOME layering

GNOME workstation is:

- `flatpak-base`
- `workstation-common`
- optional `workstation-modern`
- distro workstation drift
- `workstation-gnome`, which includes `flatpak-gnome`
- optional `workstation-gnome-modern`
- distro-specific GNOME drift where needed

Alma 9 keeps its extra GNOME delta in `recipes/layers/alma9/gnome.yml`; its modern app Flatpaks are isolated in `recipes/layers/shared/flatpak-gnome-legacy.yml`.

Alma 10 keeps only shell-version-specific dconf drift in `recipes/layers/alma10/gnome.yml`.

Fedora no longer needs a dedicated GNOME layer because the shared GNOME layers already cover its supported delta.

## COSMIC layering

COSMIC workstation is:

- `flatpak-base`
- `workstation-common`
- optional `workstation-modern`
- distro workstation drift
- distro COSMIC source layer (`alma/cosmic.yml` or `fedora/cosmic.yml`)
- `workstation-cosmic`, which includes `flatpak-cosmic`

COSMIC-specific behavior such as greeter wiring, session bits, common packages, validation, and COSMIC markers stays under `recipes/layers/shared/workstation-cosmic.yml` and `files/cosmic/**`. Alma-specific COPR source setup and selected COPR applets stay in `recipes/layers/alma/cosmic.yml`; Fedora keeps only native COSMIC config drift in `recipes/layers/fedora/cosmic.yml`.

## NVIDIA workstation extras

`recipes/layers/shared/nvidia-workstation.yml` remains the shared workstation-display NVIDIA add-on for both environments.

That keeps display/session NVIDIA extras separate from the core lane plumbing in the shared NVIDIA layers.
