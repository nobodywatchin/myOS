# Workstation Layering

Workstation is the product role. GNOME and COSMIC are implementations of that role.

## Layer order

Core Workstation recipes build in this order:

1. `layers/shared/core.yml`
2. distro core drift
3. `layers/shared/end-user-common.yml`
4. `layers/shared/workstation-common.yml`
5. distro workstation drift
6. workstation family layer
7. optional workstation NVIDIA layer when applicable

Full Workstation recipes start from the published full Server image and then add:

1. `layers/shared/end-user-common.yml`
2. `layers/shared/workstation-common.yml`
3. distro workstation drift
4. workstation family layer
5. optional workstation NVIDIA layer when applicable

## Why workstation-common stays

`workstation-common` is still the right abstraction because it keeps shared desktop behavior in one place:

- package baseline
- display-manager reconciliation helper
- workstation-only admin and diagnostics packages
- managed system Flatpak set for Workstation

That prevents GNOME and COSMIC from duplicating the same substrate.

## GNOME family

GNOME Workstation is:

- `workstation-common`
- distro workstation drift
- `workstation-gnome`
- Alma-specific GNOME drift where needed

GNOME-only behavior such as session helpers, shell integration, and GNOME markers stays under `recipes/layers/shared/workstation-gnome.yml` and `files/gnome/**`.

## COSMIC family

COSMIC Workstation is:

- `workstation-common`
- distro workstation drift
- `workstation-cosmic`

COSMIC-specific behavior such as greeter wiring, session bits, and COSMIC markers stays under `recipes/layers/shared/workstation-cosmic.yml` and `files/cosmic/**`.

## NVIDIA workstation extras

`recipes/layers/shared/nvidia-workstation.yml` remains the shared workstation-display NVIDIA add-on for both families.

That keeps display/session NVIDIA extras separate from the server-side NVIDIA lane logic.
