# Alma 9 / Alma 10 Drift Ledger

This document records the AlmaLinux 9 versus AlmaLinux 10 differences that are
currently intentional.

Default policy:

- if a change is not forced by distro packaging, platform behavior, or driver
  support, prefer the shared layers
- if a difference is intentional, keep it explicit in `recipes/layers/alma9/`
  or `recipes/layers/alma10/` and document it here

The goal is to prevent two failure modes:

1. well-meaning cleanup that removes necessary distro-specific behavior
2. lazy drift that should have stayed in a shared layer

## Shared baseline that should stay aligned

These are current cross-distro invariants unless a wider design review says
otherwise:

- `core-full-*` is the single feature-complete core tier
- `recipes/layers/shared/core.yml` is the shared core substrate
- `recipes/layers/shared/full.yml` is the shared feature-complete core composition used by the published `core-full-*` images
- `recipes/layers/shared/gnome-base.yml` is the shared GNOME add-on
- both distros keep the same dedicated tenant-account model
- both distros keep the same persistent-user enrollment model
- workstations build from the published `core-full-*` images rather than from
  AlmaLinux BootC directly
- myOS remains AI-ready across the core image family; shared ROCm userspace
  stays in the shared full-core composition unless there is a deliberate
  product change, while CUDA repo/toolkit content stays on the NVIDIA image
  paths
- NVIDIA open-stream support stays in the shared `nvidia-open` path for distros
  that support it

## Current intentional drift

## Core layer

### RamaLama packaging

- **Alma 9:** no packaged RamaLama CLI in `recipes/layers/alma9/core.yml`
- **Alma 10:** installs `ramalama` in `recipes/layers/alma10/core.yml`

Why it exists:

- Alma 10 currently has the clean packaged CLI path
- Alma 9 keeps the same surrounding platform layout without pretending the
  package exists there

Current stance:

- intentional and accepted
- treat RamaLama as an Alma 10-only operator utility for local model testing and artifact generation, not as part of the OpenClaw runtime contract
- do not invent a fake Alma 9 parity story without a real source of packages

### `just` acquisition path

- **Alma 9:** uses `scripts/just-el9.sh`
- **Alma 10:** installs `just` directly from DNF

Why it exists:

- packaging availability differs

Current stance:

- intentional packaging drift only
- the operator surface should stay the same even if the package source differs

### Locate implementation

- **Alma 9:** installs `mlocate`
- **Alma 10:** installs `plocate`

Why it exists:

- distro package split differs

Current stance:

- intentional low-level packaging drift
- no product or UX meaning should be attached to it

### EL9 compatibility shim

- **Alma 9:** creates `/usr/bin/dnf4 -> /usr/bin/dnf`
- **Alma 10:** no equivalent shim

Why it exists:

- Alma 9 compatibility expectations still exist in some tooling and muscle
  memory

Current stance:

- keep only while it solves a real EL9 compatibility problem
- do not copy it into Alma 10 just for symmetry

## Workstation layer

### GNOME stack divergence

- **Alma 9:** tracks the distro GNOME 40 workstation base and keeps a small
  delta via the `Workstation product core` group plus a focused package list
- **Alma 10:** tracks the distro GNOME 47 workstation base without the old
  GNOME backport COPR and keeps its remaining app/extension delta explicit

Why it exists:

- the distros still ship different GNOME major versions
- some app and extension choices remain shell-version-sensitive

Current stance:

- accepted compromise for now
- keep version-agnostic GNOME defaults in shared layers
- keep shell-version-sensitive app and extension choices in the Alma-specific
  workstation layers
- do not reintroduce the old Alma 10 GNOME replacement path unless packaging
  forces it again

### Default editor and image-viewer source

- **Alma 9:** adds `org.gnome.TextEditor` and `org.gnome.Loupe` as managed
  system Flatpaks
- **Alma 10:** installs `gnome-text-editor` and `loupe` as RPMs

Why it exists:

- packaging and desktop-stack behavior differ

Current stance:

- intentional workstation UX parity via different packaging sources
- the user-facing goal is similar; the implementation is not

### Ptyxis source

- **Alma 9:** installs `app.devsuite.Ptyxis` as a managed system Flatpak
- **Alma 10:** installs `ptyxis` as an RPM

Why it exists:

- packaging and GNOME stack availability differ by distro generation

Current stance:

- intentional
- keep shared Ptyxis dconf under `/org/gnome/Ptyxis/`
- keep launcher command and desktop ID overrides in the Alma-specific GNOME
  payloads

### GNOME extensions set

- **Alma 9:** uses the shared cross-version-safe extension baseline plus the
  packaged `sound-output-device-chooser` add-on
- **Alma 10:** uses the same shared baseline plus GNOME 47-specific
  `Accent Icons` and `Quick Web Search`

Why it exists:

- extension compatibility and preferred UX still differ by shell major version

Current stance:

- intentional
- keep cross-version-safe extensions in `shared/gnome-base.yml`
- keep shell-version-specific adds in the Alma-specific workstation layers

### Extra workstation kernel arguments

- **Alma 9:** no GNOME-only kargs in the distro delta
- **Alma 10:** adds workstation kargs for sleep and legacy AMD GPU handling

Why it exists:

- Alma 10 workstation support currently needs that platform-specific behavior

Current stance:

- intentional until proven unnecessary
- if a karg becomes required on both distros, move it into the shared layer

## NVIDIA layer

### Legacy proprietary stream

- **Alma 9:** has `recipes/layers/alma9/nvidia-legacy.yml`
- **Alma 10:** does not currently have a legacy proprietary stream lane

Why it exists:

- older supported GPUs still require the proprietary driver branch and current
  repo policy keeps that path on Alma 9

Current stance:

- intentional and important
- Alma 9 legacy must stay pinned to `nvidia-driver:580`
- Alma 9 legacy must resolve to prebuilt proprietary kmods, not DKMS
- changes here require rerunning `scripts/verify-alma9-nvidia-legacy.ps1`

### Open stream

- **Alma 9 and Alma 10:** share `recipes/layers/shared/nvidia-open.yml`

Why it matters:

- this is the preferred shared lane for newer supported GPUs

Current stance:

- keep shared unless vendor or distro packaging forces a split

## What should not be “fixed” casually

Do not treat these as obvious cleanup targets without a wider design review:

- RamaLama only being packaged on Alma 10
- Alma 9 and Alma 10 using different GNOME major versions with some
  distro-specific app and extension packaging
- Alma 9 legacy NVIDIA being proprietary and pinned to `580`
- Alma 9 using a `just` bootstrap script while Alma 10 installs the package
- Alma 9 and Alma 10 using different packaging sources for some workstation apps

They may be ugly, but they are current intentional ugly.

## When to add new drift

Add a new Alma-specific delta only when at least one of these is true:

- the distro package set is genuinely different
- the service or binary does not exist on both distros
- GNOME, kernel, or driver behavior differs in a way that changes runtime
  behavior
- the vendor support matrix differs by distro

If none of those apply, the default answer should be:

- put the change in `recipes/layers/shared/`

## Review questions for future changes

When adding or editing Alma-specific behavior, answer these questions in the
review:

1. Why can this not live in a shared layer?
2. Is this packaging drift, runtime drift, or policy drift?
3. Is the divergence temporary or open-ended?
4. What should remain aligned across both distros despite this change?
5. Does `docs/image-architecture.md`, `docs/runtime-contracts.md`, or this file
   need an update?

If the answer to question 1 is weak, the change probably belongs in shared.
 this file
   need an update?

If the answer to question 1 is weak, the change probably belongs in shared.
