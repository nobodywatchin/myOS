# Workstation Layering

Workstation is the product role. GNOME and COSMIC are implementations of that role.

## Layer order

All workstation recipes build in this order:

1. distro core stack
2. `layers/shared/end-user-common.yml`
3. `layers/shared/workstation-common.yml`
4. distro workstation drift
5. environment layer
6. optional workstation NVIDIA layer when applicable

Alma 10 and Fedora 43 add one more shared layer in the middle:

- `layers/shared/workstation-modern.yml` after `workstation-common`
- `layers/shared/workstation-gnome-modern.yml` for GNOME images after `workstation-gnome.yml`

## Why workstation-common stays

`workstation-common` is still the right abstraction because it keeps shared desktop behavior in one place:

- package baseline
- display-manager reconciliation helper
- workstation-only diagnostics and admin tools
- shared workstation Flatpak defaults

That prevents GNOME and COSMIC from duplicating the same substrate.

## GNOME layering

GNOME workstation is:

- `workstation-common`
- optional `workstation-modern`
- distro workstation drift
- `workstation-gnome`
- optional `workstation-gnome-modern`
- distro-specific GNOME drift where needed

Alma 9 keeps its extra GNOME delta in `recipes/layers/alma9/gnome.yml` because that compatibility lane still needs older GNOME-specific packages and Flatpak defaults.

Alma 10 keeps only shell-version-specific dconf drift in `recipes/layers/alma10/gnome.yml`.

Fedora 43 no longer needs a dedicated GNOME layer because the shared GNOME layers already cover its supported delta.

## COSMIC layering

COSMIC workstation is:

- `workstation-common`
- optional `workstation-modern`
- distro workstation drift
- distro COSMIC source layer (`alma/cosmic.yml` or `fedora43/cosmic.yml`)
- `workstation-cosmic`

COSMIC-specific behavior such as greeter wiring, session bits, common packages, validation, and COSMIC markers stays under `recipes/layers/shared/workstation-cosmic.yml` and `files/cosmic/**`. Alma-specific COPR setup and selected COPR applets stay in `recipes/layers/alma/cosmic.yml`; Fedora keeps only native COSMIC config drift in `recipes/layers/fedora43/cosmic.yml`.

## NVIDIA workstation extras

`recipes/layers/shared/nvidia-workstation.yml` remains the shared workstation-display NVIDIA add-on for both environments.

That keeps display/session NVIDIA extras separate from the core lane plumbing in the shared NVIDIA layers.
